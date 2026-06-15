import mongoose from 'mongoose';

const LikeSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    sceneId: { type: mongoose.Schema.Types.ObjectId, ref: 'Scene', required: true }
  },
  { timestamps: true }
);

LikeSchema.index({ userId: 1, sceneId: 1 }, { unique: true });

export default mongoose.model('Like', LikeSchema);
