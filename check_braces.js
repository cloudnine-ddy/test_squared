
const fs = require('fs');
const filename = process.argv[2];
const text = fs.readFileSync(filename, 'utf8');
const lines = text.split('\n');
const stack = [];

for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    for (let j = 0; j < line.length; j++) {
        const char = line[j];
        if (char === '{' || char === '(' || char === '[') {
            stack.push({ line: i + 1, char: j + 1, type: char });
        } else if (char === '}' || char === ')' || char === ']') {
            if (stack.length === 0) {
                console.log(`Extra closing '${char}' at line ${i + 1}, char ${j + 1}`);
            } else {
                const last = stack.pop();
                const expected = last.type === '{' ? '}' : last.type === '(' ? ')' : ']';
                if (char !== expected) {
                    console.log(`Mismatch! Expected ${expected} but found ${char} at line ${i + 1}, char ${j + 1}`);
                }
            }
        }
    }
}

if (stack.length > 0) {
    console.log('Unclosed items:');
    stack.forEach(s => console.log(`${s.type} at Line ${s.line}, char ${s.char}`));
} else {
    console.log('Structure is balanced.');
}
