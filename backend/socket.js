const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');

let io;

function initSocket(httpServer, corsOptions) {
  io = new Server(httpServer, {
    cors: corsOptions,
  });

  // Authenticate every Socket.io connection via JWT cookie or Bearer token
  io.use((socket, next) => {
    try {
      const token =
        socket.handshake.auth?.token ||
        socket.handshake.headers?.cookie
          ?.split(';')
          .map((c) => c.trim())
          .find((c) => c.startsWith('token='))
          ?.split('=')[1];

      if (!token) return next(new Error('Authentication required.'));
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.user = decoded;
      next();
    } catch {
      next(new Error('Invalid or expired token.'));
    }
  });

  io.on('connection', (socket) => {
    socket.on('join', ({ branchId }) => {
      // Only allow joining a branch the user belongs to (or superadmin/admin can join any)
      const userBranchId = socket.user?.branchId;
      const role = socket.user?.role;
      const allowedRoles = ['superadmin', 'admin'];
      if (!branchId) return;
      if (allowedRoles.includes(role) || String(userBranchId) === String(branchId)) {
        socket.join('branch_' + branchId);
      }
    });
  });

  return io;
}

function emitQueueUpdate(branchId, data) {
  if (io) {
    io.to('branch_' + branchId).emit('queue:updated', data);
  }
}

function getIO() {
  return io;
}

module.exports = { initSocket, emitQueueUpdate, getIO };
