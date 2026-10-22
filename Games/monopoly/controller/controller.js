(() => {
  const status = document.getElementById('status');
  const controller = new StarGamesController('monopoly', {
    connected(player) {
      document.getElementById('identity').textContent = player.display_name;
      status.textContent = 'The host is choosing Classic or Deal.';
    },
    disconnected() { status.textContent = 'Reconnecting…'; },
    error(error) { status.textContent = error.message; }
  });
  controller.connect();
})();
