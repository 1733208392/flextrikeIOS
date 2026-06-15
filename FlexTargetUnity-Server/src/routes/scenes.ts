import express from 'express';
import mongoose from 'mongoose';
import Scene from '../models/Scene';
import Like from '../models/Like';
import User from '../models/User';
import { AuthedRequest, requireAuth } from '../middleware/auth';

const router = express.Router();

// GET /api/scenes
router.get('/', async (req, res) => {
  const page = Number(req.query.page ?? 1);
  const limit = Number(req.query.limit ?? 20);
  const skip = Math.max(0, (page - 1) * limit);

  const [items, total] = await Promise.all([
    Scene.find().sort({ likes: -1, downloads: -1, createdAt: -1 }).skip(skip).limit(limit).lean(),
    Scene.countDocuments()
  ]);

  res.json({ page, limit, total, items });
});

// GET /api/scenes/:id
router.get('/:id', async (req, res) => {
  if (!mongoose.isValidObjectId(req.params.id)) {
    res.status(400).json({ message: 'invalid scene id' });
    return;
  }

  const scene = await Scene.findById(req.params.id).lean();
  if (!scene) {
    res.status(404).json({ message: 'scene not found' });
    return;
  }

  res.json(scene);
});

// POST /api/scenes
router.post('/', requireAuth, async (req: AuthedRequest, res) => {
  const { sceneName, author, createTime, shootingPositions, targets, walls, movePath, json } = req.body;
  if (!sceneName || !author || !createTime || !json) {
    res.status(400).json({ message: 'missing required scene fields' });
    return;
  }

  const scene = await Scene.create({
    sceneName,
    author,
    ownerUserId: req.userId,
    createTime,
    shootingPositions: shootingPositions ?? [],
    targets: targets ?? [],
    walls: walls ?? [],
    movePath: movePath ?? [],
    json
  });

  await User.updateOne({ _id: req.userId }, { $addToSet: { scenes: scene._id } });
  res.status(201).json(scene);
});

// PUT /api/scenes/:id
router.put('/:id', requireAuth, async (req: AuthedRequest, res) => {
  const scene = await Scene.findById(req.params.id);
  if (!scene) {
    res.status(404).json({ message: 'scene not found' });
    return;
  }

  if (scene.ownerUserId.toString() !== req.userId) {
    res.status(403).json({ message: 'not owner' });
    return;
  }

  scene.sceneName = req.body.sceneName ?? scene.sceneName;
  scene.json = req.body.json ?? scene.json;
  scene.shootingPositions = req.body.shootingPositions ?? scene.shootingPositions;
  scene.targets = req.body.targets ?? scene.targets;
  scene.walls = req.body.walls ?? scene.walls;
  scene.movePath = req.body.movePath ?? scene.movePath;

  await scene.save();
  res.json(scene);
});

// DELETE /api/scenes/:id
router.delete('/:id', requireAuth, async (req: AuthedRequest, res) => {
  const scene = await Scene.findById(req.params.id);
  if (!scene) {
    res.status(404).json({ message: 'scene not found' });
    return;
  }

  if (scene.ownerUserId.toString() !== req.userId) {
    res.status(403).json({ message: 'not owner' });
    return;
  }

  await Like.deleteMany({ sceneId: scene._id });
  await User.updateOne({ _id: req.userId }, { $pull: { scenes: scene._id } });
  await scene.deleteOne();
  res.status(204).end();
});

// POST /api/scenes/:id/like
router.post('/:id/like', requireAuth, async (req: AuthedRequest, res) => {
  const scene = await Scene.findById(req.params.id);
  if (!scene) {
    res.status(404).json({ message: 'scene not found' });
    return;
  }

  const existing = await Like.findOne({ userId: req.userId, sceneId: scene._id });
  if (existing) {
    res.status(200).json({ message: 'already liked', likes: scene.likes });
    return;
  }

  await Like.create({ userId: req.userId, sceneId: scene._id });
  scene.likes += 1;
  await scene.save();
  res.json({ likes: scene.likes });
});

// GET /api/scenes/:id/download
router.get('/:id/download', async (req, res) => {
  const scene = await Scene.findById(req.params.id);
  if (!scene) {
    res.status(404).json({ message: 'scene not found' });
    return;
  }

  scene.downloads += 1;
  await scene.save();
  res.json({ sceneId: scene._id, json: scene.json, downloads: scene.downloads });
});

export default router;
