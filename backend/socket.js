const { Server } = require('socket.io');

let io;

function initSocket(httpServer, corsOptions) {
  io = new Server(httpServer, {
    cors: corsOptions,
  });

  io.on('connection', (socket) => {
    socket.on('join', ({ branchId }) => {
      if (branchId) {
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
