const express = require("express");
const cors = require("cors");

const app = express();

app.use(cors());

app.get("/", (req, res) => {
  res.send("API is working!");
});

app.listen(3000, "0.0.0.0", () => {
  console.log("Server running on port 3000");
});