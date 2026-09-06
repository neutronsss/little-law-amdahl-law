const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 3001;

const server = http.createServer((req, res) => {
    const filePath = path.join(__dirname, req.url);
    fs.readFile(filePath, (err, data) => {
        if (err) {
            res.writeHead(404);
            res.end('Not Found');
            return;
        }
        res.writeHead(200);
        res.end(data);
    });
});

server.listen(PORT, () => {
    console.log(`[node-${PORT}] Server running at http://localhost:${PORT}/`)
});
