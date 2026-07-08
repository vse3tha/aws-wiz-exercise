const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const os = require('os');

const app = express();
const port = process.env.PORT || 3000;
const mongoUri = process.env.MONGO_URI;

if (!mongoUri) {
  console.error('MONGO_URI environment variable is required');
  process.exit(1);
}

app.use(cors());
app.use(express.json());

const todoSchema = new mongoose.Schema({
  text: { type: String, required: true },
  completed: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

const Todo = mongoose.model('Todo', todoSchema);

app.get('/healthz', async (req, res) => {
  res.json({ status: 'ok', host: os.hostname(), mongoState: mongoose.connection.readyState });
});

app.get('/api/todos', async (req, res) => {
  const todos = await Todo.find().sort({ createdAt: -1 }).limit(50);
  res.json(todos);
});

app.post('/api/todos', async (req, res) => {
  const text = String(req.body.text || '').trim();
  if (!text) {
    return res.status(400).json({ error: 'text is required' });
  }
  const todo = await Todo.create({ text });
  res.status(201).json(todo);
});

app.patch('/api/todos/:id', async (req, res) => {
  const todo = await Todo.findByIdAndUpdate(req.params.id, { completed: !!req.body.completed }, { new: true });
  if (!todo) return res.status(404).json({ error: 'not found' });
  res.json(todo);
});

app.get('/', (req, res) => {
  res.type('html').send(`<!doctype html>
<html>
<head>
  <title>Wiz Exercise Todo</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body { font-family: system-ui, sans-serif; max-width: 760px; margin: 40px auto; padding: 0 16px; }
    input { padding: 10px; width: 70%; }
    button { padding: 10px 14px; }
    li { margin: 8px 0; }
    code { background: #eee; padding: 2px 4px; }
  </style>
</head>
<body>
  <h1>Wiz Exercise Todo</h1>
  <p>Containerized Node.js app on EKS using MongoDB on EC2.</p>
  <form id="form">
    <input id="text" placeholder="Add a todo" />
    <button>Add</button>
  </form>
  <ul id="todos"></ul>
  <p><small>Pod host: <code>${os.hostname()}</code></small></p>
  <script>
    async function load() {
      const r = await fetch('/api/todos');
      const todos = await r.json();
      document.querySelector('#todos').innerHTML = todos.map(t => '<li>' + t.text + '</li>').join('');
    }
    document.querySelector('#form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const text = document.querySelector('#text').value;
      await fetch('/api/todos', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({text}) });
      document.querySelector('#text').value = '';
      load();
    });
    load();
  </script>
</body>
</html>`);
});

mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 5000 })
  .then(() => {
    app.listen(port, () => console.log(`todo app listening on ${port}`));
  })
  .catch((err) => {
    console.error('MongoDB connection failed', err);
    process.exit(1);
  });
