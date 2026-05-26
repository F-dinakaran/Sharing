require("dotenv").config();

const express = require("express");
const mongoose = require("mongoose");
const http = require("http");
const path = require("path");
const jwt = require("jsonwebtoken");
const { Server } = require("socket.io");

const User = require("./models/user");
const Patient = require("./models/patient");
const Message = require("./models/message");
const Availability = require("./models/availability");

const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB Atlas connected successfully"))
  .catch((err) => console.error("MongoDB connection error:", err));

function createToken(user) {
  return jwt.sign(
    {
      id: user._id,
      role: user.role,
      fullName: user.fullName,
    },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );
}

function createPrivateRoomId(userId1, userId2) {
  return [userId1.toString(), userId2.toString()].sort().join("_");
}

function auth(req, res, next) {
  const token = req.headers.authorization?.split(" ")[1];

  if (!token) {
    return res.status(401).json({ message: "No token provided" });
  }

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ message: "Invalid or expired token" });
  }
}

// REGISTER
app.post("/api/register", async (req, res) => {
  try {
    const {
      fullName,
      email,
      password,
      role,
      speciality,
      age,
      condition,
      termsAccepted,
    } = req.body;

    if (!termsAccepted) {
      return res.status(400).json({
        message: "You must accept the Terms and Conditions to register.",
      });
    }

    if (!fullName || !email || !password || !role) {
      return res.status(400).json({
        message: "Full name, email, password and role are required",
      });
    }

    if (!["doctor", "patient"].includes(role)) {
      return res.status(400).json({
        message: "Role must be either doctor or patient",
      });
    }

    const existingUser = await User.findOne({ email });

    if (existingUser) {
      return res.status(400).json({
        message: "This email is already registered",
      });
    }

    const user = await User.create({
      fullName,
      email,
      password,
      role,
      speciality: role === "doctor" ? speciality : "",
      termsAccepted: true,
      termsAcceptedAt: new Date(),
    });

    if (role === "patient") {
      await Patient.create({
        user: user._id,
        age,
        condition: condition || "Cardiac patient",
      });
    }

    res.status(201).json({
      message: "Account created successfully",
      token: createToken(user),
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "Registration failed",
      error: error.message,
    });
  }
});

// LOGIN
app.post("/api/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });

    if (!user || !(await user.matchPassword(password))) {
      return res.status(401).json({
        message: "Invalid email or password",
      });
    }

    res.json({
      message: "Login successful",
      token: createToken(user),
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        role: user.role,
      },
    });
  } catch (error) {
    res.status(500).json({
      message: "Login failed",
      error: error.message,
    });
  }
});

// USERS
app.get("/api/users", auth, async (req, res) => {
  const users = await User.find({ _id: { $ne: req.user.id } })
    .select("-password")
    .sort({ role: 1, fullName: 1 });

  res.json(users);
});

app.get("/api/doctors", auth, async (req, res) => {
  const doctors = await User.find({ role: "doctor" })
    .select("-password")
    .sort({ fullName: 1 });

  res.json(doctors);
});

app.get("/api/patients", auth, async (req, res) => {
  const patients = await User.find({ role: "patient" })
    .select("-password")
    .sort({ fullName: 1 });

  res.json(patients);
});

// MESSAGES
app.get("/api/messages/public", auth, async (req, res) => {
  const messages = await Message.find({ chatType: "public" })
    .populate("sender", "fullName role avatar")
    .sort({ createdAt: 1 });

  res.json(messages);
});

app.get("/api/messages/private/:otherUserId", auth, async (req, res) => {
  const roomId = createPrivateRoomId(req.user.id, req.params.otherUserId);

  const messages = await Message.find({
    chatType: "private",
    roomId,
  })
    .populate("sender", "fullName role avatar")
    .populate("receiver", "fullName role avatar")
    .sort({ createdAt: 1 });

  res.json(messages);
});

// DOCTOR CREATES AVAILABILITY
// DOCTOR CREATES AVAILABILITY RANGE
app.post("/api/availability", auth, async (req, res) => {
  try {
    const { date, startTime, endTime, duration } = req.body;

    if (req.user.role !== "doctor") {
      return res.status(403).json({
        message: "Only doctors can create availability slots.",
      });
    }

    if (!date || !startTime || !endTime || !duration) {
      return res.status(400).json({
        message: "Date, start time, end time and duration are required.",
      });
    }

    function timeToMinutes(time) {
      const [hours, minutes] = time.split(":").map(Number);
      return hours * 60 + minutes;
    }

    function minutesToTime(totalMinutes) {
      const hours = Math.floor(totalMinutes / 60);
      const minutes = totalMinutes % 60;

      return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`;
    }

    const start = timeToMinutes(startTime);
    const end = timeToMinutes(endTime);
    const slotDuration = Number(duration);

    if (end <= start) {
      return res.status(400).json({
        message: "End time must be after start time.",
      });
    }

    if (slotDuration <= 0) {
      return res.status(400).json({
        message: "Duration must be greater than 0.",
      });
    }

    const slotsToCreate = [];

    for (let current = start; current + slotDuration <= end; current += slotDuration) {
      slotsToCreate.push({
        doctor: req.user.id,
        date,
        time: minutesToTime(current),
        duration: slotDuration,
      });
    }

    if (!slotsToCreate.length) {
      return res.status(400).json({
        message: "The selected time range is too short for this appointment length.",
      });
    }

    const createdSlots = await Availability.insertMany(slotsToCreate);

    res.status(201).json({
      message: `${createdSlots.length} availability slots created.`,
      slots: createdSlots,
    });
  } catch (error) {
    res.status(500).json({
      message: "Could not create availability slots.",
      error: error.message,
    });
  }
});

// GET AVAILABLE SLOTS FOR PATIENTS
app.get("/api/availability/available", auth, async (req, res) => {
  try {
    const slots = await Availability.find({ status: "available" })
      .populate("doctor", "fullName speciality email")
      .sort({ date: 1, time: 1 });

    res.json(slots);
  } catch (error) {
    res.status(500).json({
      message: "Could not load available slots.",
      error: error.message,
    });
  }
});

// GET MY SLOTS/APPOINTMENTS
app.get("/api/availability/my", auth, async (req, res) => {
  try {
    const filter =
      req.user.role === "doctor"
        ? { doctor: req.user.id }
        : { bookedBy: req.user.id };

    const slots = await Availability.find(filter)
      .populate("doctor", "fullName speciality email")
      .populate("bookedBy", "fullName email role")
      .sort({ date: 1, time: 1 });

    res.json(slots);
  } catch (error) {
    res.status(500).json({
      message: "Could not load appointments.",
      error: error.message,
    });
  }
});

// PATIENT BOOKS AVAILABLE SLOT
app.patch("/api/availability/:id/book", auth, async (req, res) => {
  try {
    const { reason } = req.body;

    if (req.user.role !== "patient") {
      return res.status(403).json({
        message: "Only patients can book appointments.",
      });
    }

    const slot = await Availability.findOneAndUpdate(
      {
        _id: req.params.id,
        status: "available",
      },
      {
        status: "booked",
        bookedBy: req.user.id,
        reason: reason || "",
      },
      { new: true }
    )
      .populate("doctor", "fullName speciality email")
      .populate("bookedBy", "fullName email role");

    if (!slot) {
      return res.status(404).json({
        message: "This slot is no longer available.",
      });
    }

    res.json({
      message: "Appointment booked successfully.",
      slot,
    });
  } catch (error) {
    res.status(500).json({
      message: "Could not book appointment.",
      error: error.message,
    });
  }
});

// DOCTOR DELETES AVAILABLE SLOT
app.delete("/api/availability/:id", auth, async (req, res) => {
  try {
    if (req.user.role !== "doctor") {
      return res.status(403).json({
        message: "Only doctors can delete slots.",
      });
    }

    const slot = await Availability.findOneAndDelete({
      _id: req.params.id,
      doctor: req.user.id,
      status: "available",
    });

    if (!slot) {
      return res.status(404).json({
        message: "Slot not found or already booked.",
      });
    }

    res.json({ message: "Availability slot deleted." });
  } catch (error) {
    res.status(500).json({
      message: "Could not delete slot.",
      error: error.message,
    });
  }
});

// SOCKET.IO
io.on("connection", (socket) => {
  console.log("New socket connected:", socket.id);

  socket.on("userOnline", async ({ userId }) => {
    try {
      socket.userId = userId;
      socket.join(userId);

      await User.findByIdAndUpdate(userId, {
        isOnline: true,
        lastSeen: new Date(),
      });

      io.emit("onlineStatusChanged", {
        userId,
        isOnline: true,
      });
    } catch (error) {
      console.error("Online status error:", error.message);
    }
  });

  socket.on("joinPublicChat", () => {
    socket.join("public_cardio_chat");
  });

  socket.on("joinPrivateChat", ({ userId, otherUserId }) => {
    const roomId = createPrivateRoomId(userId, otherUserId);
    socket.join(roomId);
  });

  socket.on("typing", ({ chatType, userId, fullName, receiverId }) => {
    if (chatType === "public") {
      socket.to("public_cardio_chat").emit("typing", { fullName });
    } else {
      const roomId = createPrivateRoomId(userId, receiverId);
      socket.to(roomId).emit("typing", { fullName });
    }
  });

  socket.on("stopTyping", ({ chatType, userId, receiverId }) => {
    if (chatType === "public") {
      socket.to("public_cardio_chat").emit("stopTyping");
    } else {
      const roomId = createPrivateRoomId(userId, receiverId);
      socket.to(roomId).emit("stopTyping");
    }
  });

  socket.on("sendPublicMessage", async ({ senderId, text }) => {
    try {
      if (!senderId || !text) return;

      const message = await Message.create({
        chatType: "public",
        sender: senderId,
        roomId: "public_cardio_chat",
        text,
        seenBy: [senderId],
      });

      const populatedMessage = await message.populate(
        "sender",
        "fullName role avatar"
      );

      io.to("public_cardio_chat").emit(
        "receivePublicMessage",
        populatedMessage
      );
    } catch (error) {
      console.error("Public message error:", error.message);
    }
  });

  socket.on("sendPrivateMessage", async ({ senderId, receiverId, text }) => {
    try {
      if (!senderId || !receiverId || !text) return;

      const roomId = createPrivateRoomId(senderId, receiverId);

      const message = await Message.create({
        chatType: "private",
        sender: senderId,
        receiver: receiverId,
        roomId,
        text,
        seenBy: [senderId],
      });

      const populatedMessage = await message.populate([
        { path: "sender", select: "fullName role avatar" },
        { path: "receiver", select: "fullName role avatar" },
      ]);

      io.to(roomId).emit("receivePrivateMessage", populatedMessage);
    } catch (error) {
      console.error("Private message error:", error.message);
    }
  });

  socket.on("messageSeen", async ({ messageId, userId }) => {
    try {
      const message = await Message.findByIdAndUpdate(
        messageId,
        { $addToSet: { seenBy: userId } },
        { new: true }
      ).populate("sender", "fullName role avatar");

      if (message) {
        io.to(message.roomId).emit("messageSeenUpdate", message);
      }
    } catch (error) {
      console.error("Seen error:", error.message);
    }
  });

  socket.on("editMessage", async ({ messageId, newText, userId }) => {
    try {
      const message = await Message.findOneAndUpdate(
        { _id: messageId, sender: userId },
        {
          text: newText,
          edited: true,
        },
        { new: true }
      ).populate("sender", "fullName role avatar");

      if (message) {
        io.to(message.roomId).emit("messageEdited", message);
      }
    } catch (error) {
      console.error("Edit error:", error.message);
    }
  });

  socket.on("deleteMessage", async ({ messageId, userId }) => {
    try {
      const message = await Message.findOneAndUpdate(
        { _id: messageId, sender: userId },
        {
          text: "This message was deleted",
          deleted: true,
        },
        { new: true }
      ).populate("sender", "fullName role avatar");

      if (message) {
        io.to(message.roomId).emit("messageDeleted", message);
      }
    } catch (error) {
      console.error("Delete error:", error.message);
    }
  });

  socket.on("disconnect", async () => {
    try {
      if (socket.userId) {
        await User.findByIdAndUpdate(socket.userId, {
          isOnline: false,
          lastSeen: new Date(),
        });

        io.emit("onlineStatusChanged", {
          userId: socket.userId,
          isOnline: false,
        });
      }
    } catch (error) {
      console.error("Disconnect error:", error.message);
    }
  });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, () => {
  console.log(`Heartogether is running on http://localhost:${PORT}`);
});