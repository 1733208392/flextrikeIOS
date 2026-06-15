import mongoose from 'mongoose';

const SceneSchema = new mongoose.Schema({
  sceneName: { type: String, required: true },
  author: { type: String, required: true },
  ownerUserId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  createTime: { type: String, required: true },
  shootingPositions: { type: Array, default: [] },
  targets: { type: Array, default: [] },
  walls: { type: Array, default: [] },
  movePath: { type: Array, default: [] },
  downloads: { type: Number, default: 0 },
  likes: { type: Number, default: 0 },
  json: { type: String, required: true }
}, { timestamps: true });

SceneSchema.index({ likes: -1, downloads: -1, createdAt: -1 });

export default mongoose.model('Scene', SceneSchema);
