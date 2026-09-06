import http from 'k6/http';
import { check } from 'k6';

export const options = {
    vus: 50,
    duration: '20s',
    summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

const TARGET = __ENV.TARGET || 'http://localhost:8080';
const FILE = 'file-10mb.bin';

export default function () {
    const res = http.get(`${TARGET}/${FILE}`);
    check(res, {
        'status is 200': (r) => r.status === 200,
    });
}
