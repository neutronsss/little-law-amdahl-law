import http from 'k6/http';

export const options = {
    vus: 50,          // 50 user konkuren
    duration: '20s',  // durasi uji tiap file
}

const FILE = 'file-10mb.bin';

export default function () {
    http.get(`http://localhost:3001/${FILE}`);
}