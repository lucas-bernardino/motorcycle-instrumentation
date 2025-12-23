const express = require("express");
const cors = require("cors");
const app = express();
const mongoose = require("mongoose");
const { Sensor, sensorSchema } = require("./models/sensorModel");
const pl = require('nodejs-polars');
require('dotenv').config()

app.use(express.json());
app.use(cors());

const server = require('http').createServer(app);
const io = require('socket.io')(server, {
  cors: {
    origin: "*",
  }
});

let SensorModel;

let ip;

io.on('connection', (socket) => {

  console.log("Someone just connected on sockets. ID: ", socket.id);

  socket.on("send", async (data) => {
    create_sensor = await SensorModel.create(data);
    socket.broadcast.emit("send", JSON.stringify(data));
  })

});

// This route is responsible for testing if the server is on.
app.get("/teste", async (req, res) => {
  try {
    res.status(200).json("teste");
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// This route is called every time the physical button is pressed in the Raspberry Pi.
// When it's pressed, the router is responsible for creating a new model in MongoDB.
// This is useful since the user will hava multiple sets of data displayed in the page,
// allowing each of them to be downloaded
app.post("/button_pressed", async (req, res) => {
  try {
    const index_collection_name = "sensor" + req.body["contador"];
    SensorModel = mongoose.model(index_collection_name, sensorSchema);
    res.status(200).json(req.body);
  } catch (error) {
    console.log(error.message);
    res.status(500).json({ message: error.message });
  }
});

// This route will return all data associated with the last model created in the DB.
app.get("/receber", async (req, res) => {
  try {
    const sensors = await SensorModel.find({});
    res.status(200).json(sensors);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// This route will return the last set of data associated with the last model created in the DB.
// It was created to be integrated with the Chart in the page, so that every point in there is mapped
// with the last data sent in this route.
app.get("/receber_ultimo", async (req, res) => {
  try {
    const sensor_ultimo = await SensorModel.find().sort({ id: -1 }).limit(1);
    res.status(200).json(sensor_ultimo);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// This route returns a sensor data by its ID.
app.get("/receber/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const sensor = await SensorModel.findById(id);
    res.status(200).json(sensor);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// This route is called multiple times per second by the Raspberry Pi. Every time there's new data in the sensor,
// the Raspberry Pi will make a POST request to this route in order to save the data.
app.post("/enviar", async (req, res) => {
  try {
    create_sensor = await SensorModel.create(req.body);

    res.status(200).json(create_sensor);
  } catch (error) {
    console.log(error.message);
    res.status(500).json({ message: error.message });
  }
});

// Every time the Raspberry Pi 4 is turned on, it automatically sends a post request with its IP to this route.
// This happens because its IP is dynamically set, and so in order to be able to start the data acquisition
// it's first needed the IP Address to able to use SSH with it.
app.post("/ip", async (req, res) => {
  try {
    ip = req.body;
    res.status(200).json(req.body);
  } catch (error) {
    console.log(error.message);
    res.status(500).json({ message: error.message });
  }
});

// This route will return the Raspberry Pi's IP address used to run SSH.
app.get("/ip", async (req, res) => {
  try {
    res.status(200).json(ip);
  } catch (error) {
    console.log(error.message);
    res.status(500).json({ message: error.message });
  }
});

// This route is used by the client app to show all the collections that have been created.
// Keep in mind that a collection is created when the button is pressed.
app.get("/collections", async (req, res) => {
  try {
    let arrayNames = [];
    const collectionNames = (
      await mongoose.connection.db.listCollections().toArray()
    ).map((coll) => arrayNames.push(coll.name));
    res.status(200).json({ collectionNames: arrayNames });
  } catch (error) {
    console.log(error);
    res.status(500).json({ message: error.message });
  }
});

// This router deletes the collection that was sent through the body of the request.
app.post("/delete", async (req, res) => {
  try {
    const { collectionName } = req.body;
    const deleteCollection = await mongoose.connection.db
      .collection(collectionName)
      .drop();
    res.status(200).json();
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// This route takes a collection name in the request body and returns all the data associated with it.
// It's used by the Python server to create a downloadable csv file.
app.post("/collectiondata", async (req, res) => {
  try {
    const { collectionName } = req.body;
    const collection = mongoose.connection.db.collection(collectionName);
    const collectionData = await collection.find({}).toArray();
    res.status(200).json(collectionData);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});


app.get("/download", async (req, res) => {
  try {

    let collectionName = "";

    if (req.query.collection == "last" || req.query.collection == undefined) {
      collectionName = (await mongoose.connection.db.listCollections().toArray()).pop().name;
    } else {
      collectionName = req.query.collection;
    }

    const collection = mongoose.connection.db.collection(collectionName);
    const collectionData = await collection.find({}).toArray();

    for (const doc of collectionData) {
      delete doc._id;
      delete doc.id;
      doc["createdAt"] = String(doc["createdAt"])
      delete doc.updatedAt;
      delete doc.__v;
    }

    const df = pl.DataFrame(collectionData);
    const csvData = df.toCSV();

    res.setHeader("Content-Disposition", 'attachment; filename="data.csv"');
    res.setHeader("Content-Type", "text/csv");

    res.status(200).send(csvData);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

mongoose.set("strictQuery", false);

mongoose
  .connect(
    `mongodb+srv://${process.env.MONGOOSE_USERNAME}:${process.env.MONGOOSE_PASSWORD}@cluster-tcc.woqkzqa.mongodb.net/?appName=cluster-tcc`,
  )
  .then(() => {
    console.log("Conectado ao MongoDB.");
    server.listen(3001, "127.0.0.1", () => {
      console.log("Listening to port:  " + 3001);
    });

  })
  .catch((error) => {
    console.log(error);
  });

