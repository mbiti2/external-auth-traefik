const buttons = document.querySelectorAll('.btn');
const statusMessage = document.getElementById('status-message');

buttons.forEach(button => {
  button.addEventListener('click', () => {
    const url = button.dataset.url;

    // Show message before redirecting
    statusMessage.textContent = `Redirecting to ${url}...`;

    // Small delay to show message, then redirect
    setTimeout(() => {
      window.location.href = url;
    }, 700);
  });
});
