const mongoose = require("mongoose");

const patientSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true
    },

    assignedDoctor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null
    },

    age: {
      type: Number,
      min: 0
    },

    condition: {
      type: String,
      default: "Cardiac patient"
    },

    emergencyContact: {
      name: String,
      phone: String
    },

    notes: {
      type: String,
      default: ""
    }
  },
  { timestamps: true }
);

module.exports = mongoose.model("Patient", patientSchema);