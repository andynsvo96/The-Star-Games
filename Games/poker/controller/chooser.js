const pokerChooser = new StarGamesController("poker", {connected: () => {}, disconnected: () => { document.getElementById("status").textContent = "Reconnecting?"; }}); pokerChooser.connect();
