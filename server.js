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
const Appointment = require("./models/appointment");

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
    const { fullName, email, password, role, speciality, age, condition, termsAccepted } =
     req.body;
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

    if (!email || !password) {
      return res.status(400).json({
        message: "Email and password are required",
      });
    }

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

// CURRENT USER
app.get("/api/me", auth, async (req, res) => {
  const user = await User.findById(req.user.id).select("-password");
  res.json(user);
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

// ASSIGN PATIENT TO DOCTOR
app.post("/api/patients/assign-doctor", auth, async (req, res) => {
  try {
    const { patientUserId, doctorUserId } = req.body;

    if (req.user.role !== "doctor") {
      return res.status(403).json({
        message: "Only doctors can assign patients",
      });
    }

    const patientProfile = await Patient.findOne({ user: patientUserId });

    if (!patientProfile) {
      return res.status(404).json({
        message: "Patient profile not found",
      });
    }

    patientProfile.assignedDoctor = doctorUserId;
    await patientProfile.save();

    res.json({
      message: "Patient assigned to doctor successfully",
      patientProfile,
    });
  } catch (error) {
    res.status(500).json({
      message: "Could not assign doctor",
      error: error.message,
    });
  }
});

// PUBLIC MESSAGES
app.get("/api/messages/public", auth, async (req, res) => {
  const messages = await Message.find({ chatType: "public" })
    .populate("sender", "fullName role avatar")
    .sort({ createdAt: 1 });

  res.json(messages);
});

// PRIVATE MESSAGES
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

// CREATE APPOINTMENT REQUEST
app.post("/api/appointments", auth, async (req, res) => {
  try {
    const { doctorId, date, time, reason } = req.body;

    if (req.user.role !== "patient") {
      return res.status(403).json({
        message: "Only patients can request appointments",
      });
    }

    if (!doctorId || !date || !time || !reason) {
      return res.status(400).json({
        message: "Doctor, date, time and reason are required",
      });
    }

    const appointment = await Appointment.create({
      patient: req.user.id,
      doctor: doctorId,
      date,
      time,
      reason,
    });

    const populatedAppointment = await Appointment.findById(appointment._id)
      .populate("patient", "fullName email role")
      .populate("doctor", "fullName email role speciality");

    res.status(201).json({
      message: "Appointment requested successfully",
      appointment: populatedAppointment,
    });
  } catch (error) {
    res.status(500).json({
      message: "Could not create appointment",
      error: error.message,
    });
  }
});

// GET MY APPOINTMENTS
app.get("/api/appointments", auth, async (req, res) => {
  try {
    const filter =
      req.user.role === "doctor"
        ? { doctor: req.user.id }
        : { patient: req.user.id };

    const appointments = await Appointment.find(filter)
      .populate("patient", "fullName email role")
      .populate("doctor", "fullName email role speciality")
      .sort({ createdAt: -1 });

    res.json(appointments);
  } catch (error) {
    res.status(500).json({
      message: "Could not load appointments",
      error: error.message,
    });
  }
});

// APPROVE OR REJECT APPOINTMENT
app.patch("/api/appointments/:id/status", auth, async (req, res) => {
  try {
    const { status } = req.body;

    if (req.user.role !== "doctor") {
      return res.status(403).json({
        message: "Only doctors can update appointment status",
      });
    }

    if (!["approved", "rejected"].includes(status)) {
      return res.status(400).json({
        message: "Status must be approved or rejected",
      });
    }

    const appointment = await Appointment.findOneAndUpdate(
      {
        _id: req.params.id,
        doctor: req.user.id,
      },
      { status },
      { new: true }
    )
      .populate("patient", "fullName email role")
      .populate("doctor", "fullName email role speciality");

    if (!appointment) {
      return res.status(404).json({
        message: "Appointment not found",
      });
    }

    res.json({
      message: `Appointment ${status}`,
      appointment,
    });
  } catch (error) {
    res.status(500).json({
      message: "Could not update appointment",
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
      console.log("Socket disconnected:", socket.id);

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
  console.log(`CardioCare Chat is running on http://localhost:${PORT}`);
});