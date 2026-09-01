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
interface RecoverySession {
    uid: string;
    phoneNumber: string;
    otp: string;
    expiresAt: number;
    attempts: number;
}

const recoverySessions = new Map<string, RecoverySession>();
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(ip: string): boolean {
    const now = Date.now();
    const entry = rateLimitMap.get(ip);
    if (!entry || now > entry.resetAt) {
        rateLimitMap.set(ip, { count: 1, resetAt: now + 15 * 60 * 1000 });
        return true;
    }
    if (entry.count >= 5) {
        return false;
    }
    entry.count += 1;
    return true;
}

app.post('/users/request-phone-otp', async (request, reply) => {
    const clientIp = request.ip || 'global';
    if (!checkRateLimit(clientIp)) {
        return reply.code(429).send({ message: 'Too many recovery attempts. Please try again later.' });
    }

    const { phoneNumber } = z.object({ phoneNumber: z.string().min(5) }).parse(request.body);
    const cleanPhone = phoneNumber.replace(/[\s\-()]/g, '');
    const intlPhone = cleanPhone.startsWith('0') ? `+212${cleanPhone.slice(1)}` : cleanPhone.startsWith('+') ? cleanPhone : `+${cleanPhone}`;

    let snapshot = await adminDb.collection('users').where('phoneNumber', '==', phoneNumber).get();
    if (snapshot.empty && cleanPhone !== phoneNumber) {
        snapshot = await adminDb.collection('users').where('phoneNumber', '==', cleanPhone).get();
    }
    if (snapshot.empty && intlPhone !== cleanPhone) {
        snapshot = await adminDb.collection('users').where('phoneNumber', '==', intlPhone).get();
    }

    const recoveryToken = crypto.randomUUID();

    let generatedOtp: string | undefined = undefined;

    if (!snapshot.empty) {
        const userDoc = snapshot.docs[0];
        const uid = userDoc.id;
        try {
            const authUser = await adminAuth.getUser(uid);
            if (authUser) {
                const otp = Math.floor(100000 + Math.random() * 900000).toString();
                recoverySessions.set(recoveryToken, {
                    uid,
                    phoneNumber,
                    otp,
                    expiresAt: Date.now() + 10 * 60 * 1000,
                    attempts: 0,
                });
                generatedOtp = otp;
                app.log.info(`[RECOVERY OTP GENERATED] Phone: ${phoneNumber}, OTP: ${otp}, UID: ${uid}`);
            }
        } catch (e) {
            app.log.warn(`Auth user lookup failed for UID ${uid}: ${e}`);
        }
    }

    return reply.send({
        success: true,
        message: 'If this phone number is registered, you will receive a verification code.',
        recoveryToken,
        debugOtp: generatedOtp,
    });
});

app.post('/users/verify-phone-otp-and-reset-password', async (request, reply) => {
    const body = z.object({
        recoveryToken: z.string().min(1),
        otp: z.string().length(6),
        newPassword: z.string().min(6).regex(/^\d+$/, 'Password must contain numbers only'),
    }).parse(request.body);

    const session = recoverySessions.get(body.recoveryToken);
    if (!session) {
        return reply.code(400).send({ message: 'Invalid or expired verification session.' });
    }

    if (Date.now() > session.expiresAt) {
        recoverySessions.delete(body.recoveryToken);
        return reply.code(400).send({ message: 'Verification code has expired. Please request a new code.' });
    }

    session.attempts += 1;
    if (session.attempts > 5) {
        recoverySessions.delete(body.recoveryToken);
        return reply.code(400).send({ message: 'Too many failed verification attempts. Session invalidated.' });
    }

    if (session.otp !== body.otp) {
        return reply.code(400).send({ message: 'Invalid verification code.' });
    }

    try {
        const authUser = await adminAuth.getUser(session.uid);
        if (!authUser) {
            recoverySessions.delete(body.recoveryToken);
            return reply.code(404).send({ message: 'Target user account not found.' });
        }

        await adminAuth.updateUser(session.uid, { password: body.newPassword });
        recoverySessions.delete(body.recoveryToken);

        return reply.send({
            success: true,
            message: 'Password updated successfully for your account!',
        });
    } catch (error) {
        app.log.error(error);
        return reply.code(500).send({ message: 'Failed to update password for account.' });
    }
});

app.post('/qr-codes', async (_, reply) => reply.code(201).send({ id: crypto.randomUUID(), expiresAt: new Date(Date.now() + 300000).toISOString() }));

app.listen({ host: '0.0.0.0', port: Number(process.env.PORT ?? 8080) });