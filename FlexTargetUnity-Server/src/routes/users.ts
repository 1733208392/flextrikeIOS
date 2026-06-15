import express from 'express';
import Scene from '../models/Scene';
import { AuthedRequest, requireAuth } from '../middleware/auth';

const router = express.Router();

// GET /api/users/me/scenes
router.get('/me/scenes', requireAuth, async (req: AuthedRequest, res) => {
  const scenes = await Scene.find({ ownerUserId: req.userId }).sort({ createdAt: -1 }).lean();
  res.json(scenes);
});

export default router;
