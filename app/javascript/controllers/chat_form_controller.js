import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "submitButton"]

  connect() {
    console.log("Chat form controller connected")
  }

  handleKeydown(event) {
    // Submit on Enter (without Shift for new line)
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.handleSubmit(event)
    }
  }

  handleSubmit(event) {
    event.preventDefault()
    
    const content = this.inputTarget.value.trim()
    if (!content) return

    // Disable form and show loading state
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.innerHTML = '<i class="bi bi-hourglass-split"></i> Sending...'

    // Add user message immediately
    this.addUserMessage(content)

    // Show AI typing indicator
    this.showTypingIndicator()

    // Clear input
    this.inputTarget.value = ''

    // Manually submit the form with the captured content
    const formData = new FormData(this.element)
    formData.set('content', content)
    
    fetch(this.element.action, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    })
    .then(response => response.text())
    .then(html => {
      // Parse and apply Turbo Stream response
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')
      const turboStreams = doc.querySelectorAll('turbo-stream')
      
      turboStreams.forEach(stream => {
        const action = stream.getAttribute('action')
        const targetId = stream.getAttribute('target')
        const template = stream.querySelector('template')
        
        if (targetId && template) {
          const targetElement = document.getElementById(targetId)
          if (targetElement) {
            if (action === 'update') {
              targetElement.innerHTML = template.innerHTML
            } else if (action === 'append') {
              targetElement.insertAdjacentHTML('beforeend', template.innerHTML)
            }
          }
        }
      })
      
      // Hide typing indicator
      this.hideTypingIndicator()
      
      // Re-enable form
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.innerHTML = '<i class="bi bi-send"></i>'
      
      // Focus back on input
      this.inputTarget.focus()
      
      // Scroll to bottom
      this.scrollToBottom()
    })
    .catch(error => {
      console.error('Error submitting message:', error)
      
      // Hide typing indicator
      this.hideTypingIndicator()
      
      // Re-enable form
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.innerHTML = '<i class="bi bi-send"></i>'
      
      // Show error message
      alert('Error sending message. Please try again.')
    })
  }

  addUserMessage(content) {
    const chatMessages = document.getElementById('chat-messages')
    const messageHtml = `
      <div class="message mb-3 user-message">
        <div class="d-flex justify-content-end">
          <div class="message-bubble bg-primary text-white p-3 rounded" style="max-width: 70%;">
            <div class="message-header mb-2">
              <small class="text-white-50">
                <i class="bi bi-person"></i>
                You
                <span class="ms-2">${new Date().toLocaleTimeString()}</span>
              </small>
            </div>
            <div class="message-content">
              <div class="message-text">
                ${content.replace(/\n/g, '<br>')}
              </div>
            </div>
          </div>
        </div>
      </div>
    `
    chatMessages.insertAdjacentHTML('beforeend', messageHtml)
    this.scrollToBottom()
  }

  showTypingIndicator() {
    const typingIndicator = document.getElementById('ai-typing')
    if (typingIndicator) {
      typingIndicator.style.display = 'block'
      this.scrollToBottom()
    }
  }

  hideTypingIndicator() {
    const typingIndicator = document.getElementById('ai-typing')
    if (typingIndicator) {
      typingIndicator.style.display = 'none'
    }
  }

  scrollToBottom() {
    const chatMessages = document.getElementById('chat-messages')
    if (chatMessages) {
      chatMessages.scrollTop = chatMessages.scrollHeight
    }
  }

  clearForm() {
    this.inputTarget.value = ''
    this.inputTarget.focus()
  }
} 