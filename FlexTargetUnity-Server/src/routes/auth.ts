import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import User from '../models/User';

const router = express.Router();

router.post('/register', async (req, res) => {
  const { username, password } = req.body as { username?: string; password?: string };
  if (!username || !password) {
    res.status(400).json({ message: 'username and password required' });
    return;
  }

  const existing = await User.findOne({ username });
  if (existing) {
    res.status(409).json({ message: 'username already exists' });
    return;
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await User.create({ username, passwordHash, scenes: [] });
  res.status(201).json({ id: user._id.toString(), username: user.username });
});

router.post('/login', async (req, res) => {
  const { username, password } = req.body as { username?: string; password?: string };
  if (!username || !password) {
    res.status(400).json({ message: 'username and password required' });
    return;
  }

  const user = await User.findOne({ username });
  if (!user) {
    res.status(401).json({ message: 'invalid credentials' });
    return;
  }

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) {
    res.status(401).json({ message: 'invalid credentials' });
    return;
  }

  const token = jwt.sign({ sub: user._id.toString(), username: user.username }, process.env.JWT_SECRET ?? 'dev-secret', {
    expiresIn: '7d'
  });

  res.json({ token, user: { id: user._id.toString(), username: user.username } });
});

router.post('/refresh', async (req, res) => {
  const { userId, username } = req.body as { userId?: string; username?: string };
  if (!userId || !username) {
    res.status(400).json({ message: 'userId and username required' });
    return;
  }

  const token = jwt.sign({ sub: userId, username }, process.env.JWT_SECRET ?? 'dev-secret', {
    expiresIn: '7d'
  });

  res.json({ token });
});

export default router;
