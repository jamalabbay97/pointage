import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from 'jsonwebtoken';
import { initializeApp, applicationDefault, cert, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { z } from 'zod';

const app = Fastify({ logger: true });
await app.register(cors, { origin: true });
const secret = process.env.JWT_SECRET ?? 'change-me';
const attendanceSchema = z.object({ employeeId: z.string(), qrPayload: z.string(), latitude: z.number(), longitude: z.number(), deviceId: z.string(), idempotencyKey: z.string() });
const deleteUserParamsSchema = z.object({ id: z.string().min(1) });
const lookupUserByEmailParamsSchema = z.object({ email: z.string().email() });

if (getApps().length === 0) {
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    initializeApp(serviceAccountJson
        ? { credential: cert(JSON.parse(serviceAccountJson)) }
        : { credential: applicationDefault() });
}

const adminAuth = getAuth();
const adminDb = getFirestore();

async function requireAdminOrManager(idToken?: string) {
    if (!idToken) {
        throw Object.assign(new Error('Missing bearer token'), { statusCode: 401 });
    }

    const decoded = await adminAuth.verifyIdToken(idToken);
    const requesterDoc = await adminDb.collection('users').doc(decoded.uid).get();
    const requester = requesterDoc.data();
    const role = String(requester?.role ?? '').trim().toLowerCase();
    const status = String(requester?.status ?? 'active').trim().toLowerCase();

    if (!requesterDoc.exists || status !== 'active' || !['admin', 'manager'].includes(role)) {
        throw Object.assign(new Error('Insufficient permissions'), { statusCode: 403 });
    }

    return { uid: decoded.uid, role };
}

async function deleteQueryBatch(collection: string, field: string, value: string) {
    const snapshot = await adminDb.collection(collection).where(field, '==', value).get();
    if (snapshot.empty) return 0;

    let deleted = 0;
    for (let i = 0; i < snapshot.docs.length; i += 500) {
        const batch = adminDb.batch();
        for (const doc of snapshot.docs.slice(i, i + 500)) {
            batch.delete(doc.ref);
            deleted += 1;
        }
        await batch.commit();
    }
    return deleted;
}

app.post('/login', async (request, reply) => {
    const body = z.object({ email: z.string().email(), password: z.string().min(8) }).parse(request.body);
    return reply.send({ accessToken: jwt.sign({ sub: body.email, role: 'employee' }, secret, { expiresIn: '15m' }), refreshToken: jwt.sign({ sub: body.email, typ: 'refresh' }, secret, { expiresIn: '30d' }) });
});
app.post('/logout', async (_, reply) => reply.code(204).send());
app.post('/attendance', async (request, reply) => reply.code(201).send({ id: crypto.randomUUID(), ...attendanceSchema.parse(request.body), status: 'present' }));
app.get('/history/:employeeId', async () => ({ records: [] }));
app.get('/reports', async () => ({ totalPresent: 0, late: 0, absent: 0 }));
app.get('/users/lookup-by-email/:email', async (request, reply) => {
    const authHeader = request.headers.authorization ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice('Bearer '.length) : undefined;
    await requireAdminOrManager(token);
    const { email } = lookupUserByEmailParamsSchema.parse({
        email: decodeURIComponent((request.params as { email: string }).email),
    });

    try {
        const authUser = await adminAuth.getUserByEmail(email);
        const firestoreDoc = await adminDb.collection('users').doc(authUser.uid).get();
        return reply.send({
            uid: authUser.uid,
            hasFirestoreProfile: firestoreDoc.exists,
        });
    } catch (error) {
        if ((error as { code?: string }).code === 'auth/user-not-found') {
            return reply.send({ uid: null, hasFirestoreProfile: false });
        }
        throw error;
    }
});
app.get('/users/:id', async (request) => ({ id: (request.params as { id: string }).id }));
app.patch('/users/:id', async (request) => ({ id: (request.params as { id: string }).id, ...request.body as object }));
app.delete('/users/:id', async (request, reply) => {
    const authHeader = request.headers.authorization ?? '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice('Bearer '.length) : undefined;
    const requester = await requireAdminOrManager(token);
    const { id: uidToDelete } = deleteUserParamsSchema.parse(request.params);

    if (requester.uid === uidToDelete) {
        return reply.code(400).send({ message: 'You cannot delete your own account.' });
    }

    const userDoc = adminDb.collection('users').doc(uidToDelete);
    const userSnapshot = await userDoc.get();
    if (!userSnapshot.exists) {
        try {
            await adminAuth.deleteUser(uidToDelete);
        } catch (error) {
            if ((error as { code?: string }).code !== 'auth/user-not-found') throw error;
        }
        return reply.code(204).send();
    }

    const userData = userSnapshot.data();
    if (requester.role === 'manager' && userData?.managerId !== requester.uid && String(userData?.createdBy ?? '') !== requester.uid) {
        return reply.code(403).send({ message: 'Managers can delete only users they created or manage.' });
    }

    const batch = adminDb.batch();
    batch.delete(userDoc);
    batch.delete(adminDb.collection('devices').doc(uidToDelete));
    await batch.commit();

    await Promise.all([
        deleteQueryBatch('attendance', 'uid', uidToDelete),
        deleteQueryBatch('attendance', 'userId', uidToDelete),
        deleteQueryBatch('logs', 'uid', uidToDelete),
        deleteQueryBatch('logs', 'userId', uidToDelete),
        deleteQueryBatch('devices', 'uid', uidToDelete),
        deleteQueryBatch('devices', 'userId', uidToDelete),
    ]);

    try {
        await adminAuth.deleteUser(uidToDelete);
    } catch (error) {
        if ((error as { code?: string }).code !== 'auth/user-not-found') throw error;
    }

    return reply.code(204).send();
});
app.post('/qr-codes', async (_, reply) => reply.code(201).send({ id: crypto.randomUUID(), expiresAt: new Date(Date.now() + 300000).toISOString() }));

app.listen({ host: '0.0.0.0', port: Number(process.env.PORT ?? 8080) });