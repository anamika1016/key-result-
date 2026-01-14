import "@hotwired/turbo-rails";
import "controllers";

// Flash message functionality
document.addEventListener('DOMContentLoaded', function() {
  // Auto-hide flash messages after 15 seconds (increased for better readability)
  const alerts = document.querySelectorAll('.alert');
  alerts.forEach(function(alert) {
    // Don't auto-hide error messages immediately - let them stay visible
    if (alert.classList.contains('alert-danger')) {
      // Error messages stay for 20 seconds
      setTimeout(function() {
        if (alert && alert.parentNode) {
          alert.style.transition = 'opacity 0.5s ease-out, transform 0.5s ease-out';
          alert.style.opacity = '0';
          alert.style.transform = 'translateY(-100%) translateX(-50%)';
          setTimeout(function() {
            if (alert && alert.parentNode) {
              alert.parentNode.removeChild(alert);
            }
          }, 500);
        }
      }, 20000); // 20 seconds for error messages
    } else {
      // Success messages stay for 4 seconds
      setTimeout(function() {
        if (alert && alert.parentNode) {
          alert.style.transition = 'opacity 0.5s ease-out, transform 0.5s ease-out';
          alert.style.opacity = '0';
          alert.style.transform = 'translateY(-100%) translateX(-50%)';
          setTimeout(function() {
            if (alert && alert.parentNode) {
              alert.parentNode.removeChild(alert);
            }
          }, 500);
        }
      }, 4000); // 4 seconds for success messages
    }
  });

  // Handle close button clicks
  document.addEventListener('click', function(e) {
    if (e.target.classList.contains('btn-close') || e.target.closest('.btn-close')) {
      const alert = e.target.closest('.alert');
      if (alert) {
        alert.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out';
        alert.style.opacity = '0';
        alert.style.transform = 'translateY(-100%) translateX(-50%)';
        setTimeout(function() {
          if (alert && alert.parentNode) {
            alert.parentNode.removeChild(alert);
          }
        }, 300);
      }
    }
  });
});
