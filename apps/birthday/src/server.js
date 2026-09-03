var http = require('http');

var handleRequest = function(request, response) {
  var r = Math.floor(Math.random() * 256);
  var g = Math.floor(Math.random() * 256);
  var b = Math.floor(Math.random() * 256);
  var coloredText = '\x1b[38;2;' + r + ';' + g + ';' + b + 'mHappy birthday!\x1b[0m\n';
  
  response.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  response.end(coloredText);
};

http.createServer(handleRequest).listen(8080);
