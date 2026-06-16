// JavaScript for Antigravity CLI Statusline landing page

document.addEventListener('DOMContentLoaded', () => {
  // 1. Header scroll effect
  const header = document.querySelector('header');
  window.addEventListener('scroll', () => {
    if (window.scrollY > 20) {
      header.classList.add('scrolled');
    } else {
      header.classList.remove('scrolled');
    }
  });

  // 2. Copy to Clipboard Functionality
  const copyButtons = document.querySelectorAll('.copy-btn');
  copyButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.getAttribute('data-copy-target');
      const textToCopy = document.getElementById(targetId).textContent.trim().replace(/^\$\s*/, '');
      
      navigator.clipboard.writeText(textToCopy).then(() => {
        // Show tooltip/feedback
        const tooltip = btn.nextElementSibling || btn.querySelector('.copy-tooltip');
        if (tooltip) {
          tooltip.classList.add('show');
          const originalHTML = btn.innerHTML;
          btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" style="color: #10b981;"><path d="M13.854 3.646a.5.5 0 0 1 0 .708l-7 7a.5.5 0 0 1-.708 0l-3.5-3.5a.5.5 0 1 1 .708-.708L6.5 10.293l6.646-6.647a.5.5 0 0 1 .708 0z"/></svg>`;
          
          setTimeout(() => {
            tooltip.classList.remove('show');
            btn.innerHTML = originalHTML;
          }, 2000);
        }
      }).catch(err => {
        console.error('Failed to copy: ', err);
      });
    });
  });

  // 3. Showcase Layout Tabs Toggle
  const layoutTabBtns = document.querySelectorAll('.layout-tab-btn');
  const layoutImgs = document.querySelectorAll('.layout-img');
  
  layoutTabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      layoutTabBtns.forEach(b => b.classList.remove('active'));
      layoutImgs.forEach(img => img.classList.remove('active'));
      
      btn.classList.add('active');
      const targetLayout = btn.getAttribute('data-layout');
      document.getElementById(`img-layout-${targetLayout}`).classList.add('active');
    });
  });

  // 4. Installation OS Tabs
  const installTabBtns = document.querySelectorAll('.install-tab-btn');
  const installPanes = document.querySelectorAll('.install-pane');
  
  installTabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      installTabBtns.forEach(b => b.classList.remove('active'));
      installPanes.forEach(pane => pane.classList.remove('active'));
      
      btn.classList.add('active');
      const targetOS = btn.getAttribute('data-os');
      document.getElementById(`install-${targetOS}`).classList.add('active');
    });
  });

  // 5. Interactive Terminal Statusline Preview
  const previewElement = document.getElementById('statusline-interactive-preview');
  const widthBtns = document.querySelectorAll('.width-btn');
  const fontBtns = document.querySelectorAll('.font-btn');

  let currentWidth = 'wide'; // wide, medium, small
  let currentFont = 'nerd'; // nerd, classic

  // Statusline variations data
  const statuslineData = {
    nerd: {
      wide: `
        <div class="statusline-row">
          <div class="statusline-cell">
            <span class="status-badge net-on">󰖩 ON (net)</span>
            <span class="status-badge git-branch"> main*</span>
            <span class="status-badge model">󰚏 gemini-1.5-pro</span>
          </div>
          <div class="statusline-cell">
            <div class="statusline-progress-wrapper">
              <span class="statusline-progress-label">CTX [██████████░░░░░░░░░░] 50%</span>
            </div>
            <span class="status-badge font-mono" style="background: rgba(255,255,255,0.03);">󰢱 120.4K/1.0M t</span>
            <span class="status-badge font-mono" style="background: rgba(16, 185, 129, 0.05); color: #34d399;">󰅠 5h: 90%</span>
            <span class="status-badge" style="background: rgba(255,255,255,0.03);">󱙺 2  1</span>
          </div>
        </div>
      `,
      medium: `
        <div class="statusline-row" style="border-bottom: 1px solid rgba(255,255,255,0.03); padding-bottom: 6px; margin-bottom: 4px;">
          <div class="statusline-cell">
            <span class="status-badge net-on">󰖩 ON (net)</span>
            <span class="status-badge git-branch"> main*</span>
            <span class="status-badge model">󰚏 gemini-1.5-pro</span>
          </div>
          <div class="statusline-cell">
            <span class="status-badge" style="background: rgba(255,255,255,0.03);">󱙺 2 subagents  1 task</span>
          </div>
        </div>
        <div class="statusline-row">
          <div class="statusline-cell">
            <div class="statusline-progress-wrapper" style="min-width: 100px;">
              <span class="statusline-progress-label">CTX [██████████░░░░░░░░░░] 50%</span>
            </div>
            <span style="font-size: 0.8rem; color: var(--text-muted);">120.4K/1.0M t</span>
          </div>
          <div class="statusline-cell">
            <span class="status-badge font-mono" style="background: rgba(16, 185, 129, 0.05); color: #34d399; font-size: 0.75rem;">󰅠 5h: 90%</span>
          </div>
        </div>
      `,
      small: `
        <div class="statusline-row">
          <div class="statusline-cell">
            <span class="status-badge net-on">󰖩 ON</span>
            <span class="status-badge git-branch"> main*</span>
            <span class="status-badge error">󰅠 5h: 90%</span>
          </div>
          <div class="statusline-cell">
            <span class="status-badge" style="background: rgba(255,255,255,0.03);">󱙺 2  1</span>
          </div>
        </div>
      `
    },
    classic: {
      wide: `
        <div class="statusline-row">
          <div class="statusline-cell">
            <span class="status-badge net-on">[NET_ON]</span>
            <span class="status-badge git-branch">br: main*</span>
            <span class="status-badge model">mod: gemini-1.5-pro</span>
          </div>
          <div class="statusline-cell">
            <div class="statusline-progress-wrapper">
              <span class="statusline-progress-label">CTX [**********..........] 50%</span>
            </div>
            <span class="status-badge font-mono" style="background: rgba(255,255,255,0.03);">tok: 120.4K/1.0M</span>
            <span class="status-badge font-mono" style="background: rgba(16, 185, 129, 0.05); color: #34d399;">q-5h: 90%</span>
            <span class="status-badge" style="background: rgba(255,255,255,0.03);">subs: 2 tasks: 1</span>
          </div>
        </div>
      `,
      medium: `
        <div class="statusline-row" style="border-bottom: 1px solid rgba(255,255,255,0.03); padding-bottom: 6px; margin-bottom: 4px;">
          <div class="statusline-cell">
            <span class="status-badge net-on">[NET_ON]</span>
            <span class="status-badge git-branch">br: main*</span>
            <span class="status-badge model">mod: gemini-1.5-pro</span>
          </div>
          <div class="statusline-cell">
            <span class="status-badge" style="background: rgba(255,255,255,0.03);">subs: 2 tasks: 1</span>
          </div>
        </div>
        <div class="statusline-row">
          <div class="statusline-cell">
            <div class="statusline-progress-wrapper" style="min-width: 100px;">
              <span class="statusline-progress-label">CTX [**********..........] 50%</span>
            </div>
            <span style="font-size: 0.8rem; color: var(--text-muted);">120.4K/1.0M</span>
          </div>
          <div class="statusline-cell">
            <span class="status-badge font-mono" style="background: rgba(16, 185, 129, 0.05); color: #34d399; font-size: 0.75rem;">q-5h: 90%</span>
          </div>
        </div>
      `,
      small: `
        <div class="statusline-row">
          <div class="statusline-cell">
            <span class="status-badge net-on">[NET]</span>
            <span class="status-badge git-branch">main*</span>
            <span class="status-badge error">q-5h: 90%</span>
          </div>
          <div class="statusline-cell">
            <span class="status-badge" style="background: rgba(255,255,255,0.03);">S: 2 T: 1</span>
          </div>
        </div>
      `
    }
  };

  function updateStatusline() {
    // Add visual changes to preview element
    previewElement.className = `statusline-preview ${currentWidth}`;
    previewElement.innerHTML = statuslineData[currentFont][currentWidth];
  }

  widthBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      widthBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      currentWidth = btn.getAttribute('data-width');
      updateStatusline();
    });
  });

  fontBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      fontBtns.forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      currentFont = btn.getAttribute('data-font');
      updateStatusline();
    });
  });

  // Initialize statusline preview
  updateStatusline();
});
