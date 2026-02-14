const mongoose = require('mongoose');

const sensorSchema = mongoose.Schema(
  {
    id: {
      type: Number,
      required: true,
      default: -99
    },
    acel_x: {
      type: Number,
      required: true,
      default: -99
    },
    acel_y: {
      type: Number,
      required: true,
      default: -99
    },
    acel_z: {
      type: Number,
      required: true,
      default: -99
    },
    temp: {
      type: Number,
      required: true,
      default: -99
    },
    vel_x: {
      type: Number,
      required: true,
      default: -99
    },
    vel_y: {
      type: Number,
      required: true,
      default: -99
    },
    vel_z: {
      type: Number,
      required: true,
      default: -99
    },
    roll: {
      type: Number,
      required: true,
      default: -99
    },
    pitch: {
      type: Number,
      required: true,
      default: -99
    },
    yaw: {
      type: Number,
      required: true,
      default: -99
    },
    mag_x: {
      type: Number,
      required: true,
      default: -99
    },
    mag_y: {
      type: Number,
      required: true,
      default: -99
    },
    mag_z: {
      type: Number,
      required: true,
      default: -99
    },
    press_ar: {
      type: Number,
      required: true,
      default: -99,
    },
    altitude: {
      type: Number,
      required: true,
      default: -99,
    },
    long: {
      type: Number,
      required: true,
      default: -99,
    },
    lat: {
      type: Number,
      required: true,
      default: -99,
    },
    veloc: {
      type: Number,
      required: true,
      default: -99,
    },
    esterc: {
      type: Number,
      required: true,
      default: -99,
    },
    Horario: {
      type: String,
      required: false,
      default: "foo",
    },
    rot: {
      type: Number,
      required: true,
      default: -99,
    },
    veloc_hall: {
      type: Number,
      required: true,
      default: -99,
    },
    termopar1: {
      type: Number,
      required: false,
      default: -99,
    },
    brake_pressure: {
      type: Number,
      required: false,
      default: -99,
    },
  },
  {
    timestamps: true
  }
)

const Sensor = mongoose.model('Sensor', sensorSchema);

module.exports = {
  Sensor,
  sensorSchema
};
