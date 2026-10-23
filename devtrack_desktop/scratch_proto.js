const ws = new WebSocket("ws://127.0.0.1:60839/Qa5m75Q5q9E=/ws");

ws.onopen = () => {
  ws.send(JSON.stringify({
    jsonrpc: "2.0",
    id: 2,
    method: "reloadSources",
    params: { isolateId: "1" }
  }));
};

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log("Notices:", JSON.stringify(data.result));
};

setTimeout(() => process.exit(0), 3000);
