import http from 'k6/http';
import { check } from 'k6';

const vus = __ENV.VUS ? parseInt(__ENV.VUS) : 100;
const duration = __ENV.DURATION || '600s';
const target = __ENV.TARGET || 'http://localhost:3001';
const file = __ENV.FILE || 'file-1kb.bin';

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
