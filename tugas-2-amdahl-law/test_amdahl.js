import http from 'k6/http';
import { check } from 'k6';

const vus = __ENV.VUS ? parseInt(__ENV.VUS) : 50;
const duration = __ENV.DURATION || '20s';
const target = __ENV.TARGET || 'http://localhost:8080';
const file = __ENV.FILE || 'file-10mb.bin';

export const options = {
    vus: vus,
    duration: duration,
    summaryTrendStats: ['avg', 'min', 'med', 'p(90)', 'p(95)', 'p(99)', 'max'],
};

export default function () {
    const res = http.get(`${target}/${file}`);
    check(res, {
        'status is 200': (r) => r.status === 200,
    });
}

