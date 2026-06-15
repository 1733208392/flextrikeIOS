import mongoose from 'mongoose';

const UserSchema = new mongoose.Schema({
  username: { type: String, required: true, unique: true },
  passwordHash: { type: String, required: true },
  scenes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Scene' }]
}, { timestamps: true });

export default mongoose.model('User', UserSchema);
