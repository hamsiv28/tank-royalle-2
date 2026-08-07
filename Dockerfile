// server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

const rooms = {};

function generateRoomCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

io.on('connection', (socket) => {
  let currentRoom = null;

  // Oda Oluşturma
  socket.on('createRoom', (data) => {
    const roomCode = generateRoomCode();
    rooms[roomCode] = {
      host: socket.id,
      guest: null,
      mapId: data.mapId || 1,
      players: { [socket.id]: { name: data.name, slot: 'p1' } }
    };
    socket.join(roomCode);
    currentRoom = roomCode;
    socket.emit('roomCreated', { roomCode, slot: 'p1' });
  });

  // Odaya Katılma
  socket.on('joinRoom', (data) => {
    const roomCode = data.roomCode;
    const room = rooms[roomCode];

    if (!room) {
      socket.emit('errorMsg', 'Oda bulunamadı!');
      return;
    }
    if (room.guest) {
      socket.emit('errorMsg', 'Oda dolu!');
      return;
    }

    room.guest = socket.id;
    room.players[socket.id] = { name: data.name, slot: 'p2' };
    socket.join(roomCode);
    currentRoom = roomCode;

    // Her iki tarafa oyunun başladığını bildir
    io.to(roomCode).emit('gameStart', {
      mapId: room.mapId,
      p1Name: room.players[room.host].name,
      p2Name: data.name
    });
  });

  // Oyuncu Pozisyon & Durum Senkronizasyonu
  socket.on('stateUpdate', (data) => {
    if (currentRoom) {
      socket.to(currentRoom).emit('remoteStateUpdate', data);
    }
  });

  // Ateş Etme
  socket.on('shoot', (data) => {
    if (currentRoom) {
      socket.to(currentRoom).emit('remoteShoot', data);
    }
  });

  // Yetenek Kullanımı
  socket.on('useSkill', (data) => {
    if (currentRoom) {
      socket.to(currentRoom).emit('remoteUseSkill', data);
    }
  });

  // Bağlantı Kopması
  socket.on('disconnect', () => {
    if (currentRoom && rooms[currentRoom]) {
      io.to(currentRoom).emit('playerDisconnected');
      delete rooms[currentRoom];
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Sunucu ${PORT} portunda çalışıyor.`));
