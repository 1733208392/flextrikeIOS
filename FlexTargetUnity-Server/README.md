# FlexTargetUnity-Server

Node.js (Express + MongoDB) backend for FlexTargetUnity community scene sharing.

## Endpoints
- `GET    /api/scenes` — paginated scene list
- `GET    /api/scenes/:id` — scene detail + JSON
- `POST   /api/scenes` — upload new scene (auth required)
- `PUT    /api/scenes/:id` — update own scene
- `DELETE /api/scenes/:id` — delete own scene
- `POST   /api/scenes/:id/like` — like/rate scene
- `GET    /api/scenes/:id/download` — download scene JSON
- `GET    /api/users/me/scenes` — user's own scenes

## Setup
1. `npm install`
2. `npm run dev` (requires local MongoDB)

## Notes
- Tencent COS integration and JWT auth are stubbed for now.
- See `src/models/` and `src/routes/` for schema and route stubs.