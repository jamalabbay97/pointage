import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

const app = Fastify({ logger: true });
await app.register(cors, { origin: true });
const secret = process.env.JWT_SECRET ?? 'change-me';
const attendanceSchema = z.object({ employeeId: z.string(), qrPayload: z.string(), latitude: z.number(), longitude: z.number(), deviceId: z.string(), idempotencyKey: z.string() });

app.post('/login', async (request, reply) => {
    const body = z.object({ email: z.string().email(), password: z.string().min(8) }).parse(request.body);
    return reply.send({ accessToken: jwt.sign({ sub: body.email, role: 'employee' }, secret, { expiresIn: '15m' }), refreshToken: jwt.sign({ sub: body.email, typ: 'refresh' }, secret, { expiresIn: '30d' }) });
});
app.post('/logout', async (_, reply) => reply.code(204).send());
app.post('/attendance', async (request, reply) => reply.code(201).send({ id: crypto.randomUUID(), ...attendanceSchema.parse(request.body), status: 'present' }));
app.get('/history/:employeeId', async () => ({ records: [] }));
app.get('/reports', async () => ({ totalPresent: 0, late: 0, absent: 0 }));
app.get('/users/:id', async (request) => ({ id: (request.params as { id: string }).id }));
app.patch('/users/:id', async (request) => ({ id: (request.params as { id: string }).id, ...request.body as object }));
app.post('/qr-codes', async (_, reply) => reply.code(201).send({ id: crypto.randomUUID(), expiresAt: new Date(Date.now() + 300000).toISOString() }));

app.listen({ host: '0.0.0.0', port: Number(process.env.PORT ?? 8080) });