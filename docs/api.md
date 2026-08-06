# REST API

All endpoints require HTTPS. Authenticated routes use `Authorization: Bearer <jwt>` and an `Idempotency-Key` header for writes.

- `POST /login`
- `POST /logout`
- `POST /attendance`
- `GET /history/:employeeId`
- `GET /reports`
- `GET /users/:id`
- `PATCH /users/:id`
- `GET /users/lookup-by-email/:email` - requires a Firebase ID token for an active Admin or Manager and returns `{ uid, hasFirestoreProfile }` for reconciling orphaned Auth accounts during user creation.
- `DELETE /users/:id` - requires a Firebase ID token for an active Admin Manager in `Authorization: Bearer <token>` and permanently removes the user from Firebase Authentication plus app-owned Firestore records. Managers can delete only users they created or manage.
- `POST /qr-codes`