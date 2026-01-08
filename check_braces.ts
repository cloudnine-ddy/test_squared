
const filename = Deno.args[0];
const text = await Deno.readTextFile(filename);
const lines = text.split('\n');
const stack = [];

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  for (let j = 0; j < line.length; j++) {
    const char = line[j];
    if (char === '{') {
      stack.push({ line: i + 1, char: j + 1 });
    } else if (char === '}') {
      if (stack.length === 0) {
        console.log(`Extra closing brace at line ${i + 1}, char ${j + 1}`);
      } else {
        stack.pop();
      }
    }
  }
}

if (stack.length > 0) {
  console.log('Unclosed braces:');
  stack.forEach(s => console.log(`Line ${s.line}, char ${s.char}`));
} else {
  console.log('Braces are balanced.');
}
