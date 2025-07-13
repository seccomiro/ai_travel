import { Application } from "@hotwired/stimulus"
import ChatFormController from "../../../app/javascript/controllers/chat_form_controller"

describe("ChatFormController", () => {
  let application
  let controller
  let element

  beforeEach(() => {
    // Set up DOM
    document.body.innerHTML = `
      <form data-controller="chat-form" action="/chat_sessions/1/create_message" method="post">
        <input type="text" data-chat-form-target="input" />
        <button type="submit" data-chat-form-target="submitButton">
          <i class="bi bi-send"></i>
        </button>
      </form>
      <div id="chat-messages"></div>
      <div id="ai-typing" style="display: none;">AI is typing...</div>
      <meta name="csrf-token" content="test-token" />
    `

    // Set up Stimulus application
    application = Application.start()
    application.register("chat-form", ChatFormController)
    
    element = document.querySelector('[data-controller="chat-form"]')
    controller = application.getControllerForElementAndIdentifier(element, "chat-form")
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  describe("connect", () => {
    it("logs connection message", () => {
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation()
      controller.connect()
      expect(consoleSpy).toHaveBeenCalledWith("Chat form controller connected")
      consoleSpy.mockRestore()
    })
  })

  describe("handleKeydown", () => {
    it("submits form on Enter without Shift", () => {
      const submitSpy = jest.spyOn(controller, 'handleSubmit')
      const event = new KeyboardEvent('keydown', { key: 'Enter', shiftKey: false })
      
      controller.handleKeydown(event)
      
      expect(submitSpy).toHaveBeenCalledWith(event)
      expect(event.defaultPrevented).toBe(true)
    })

    it("does not submit on Enter with Shift", () => {
      const submitSpy = jest.spyOn(controller, 'handleSubmit')
      const event = new KeyboardEvent('keydown', { key: 'Enter', shiftKey: true })
      
      controller.handleKeydown(event)
      
      expect(submitSpy).not.toHaveBeenCalled()
      expect(event.defaultPrevented).toBe(false)
    })

    it("does not submit on other keys", () => {
      const submitSpy = jest.spyOn(controller, 'handleSubmit')
      const event = new KeyboardEvent('keydown', { key: 'A' })
      
      controller.handleKeydown(event)
      
      expect(submitSpy).not.toHaveBeenCalled()
    })
  })

  describe("handleSubmit", () => {
    beforeEach(() => {
      global.fetch = jest.fn()
    })

    it("does not submit empty content", () => {
      controller.inputTarget.value = ""
      const event = { preventDefault: jest.fn() }
      
      controller.handleSubmit(event)
      
      expect(global.fetch).not.toHaveBeenCalled()
    })

    it("does not submit whitespace-only content", () => {
      controller.inputTarget.value = "   "
      const event = { preventDefault: jest.fn() }
      
      controller.handleSubmit(event)
      
      expect(global.fetch).not.toHaveBeenCalled()
    })

    it("submits valid content", () => {
      controller.inputTarget.value = "Hello AI"
      const event = { preventDefault: jest.fn() }
      
      global.fetch.mockResolvedValueOnce({
        text: () => Promise.resolve('<turbo-stream action="append" target="chat-messages"><template>Response</template></turbo-stream>')
      })

      controller.handleSubmit(event)
      
      expect(event.preventDefault).toHaveBeenCalled()
      expect(global.fetch).toHaveBeenCalledWith(
        controller.element.action,
        expect.objectContaining({
          method: 'POST',
          body: expect.any(FormData),
          headers: expect.objectContaining({
            'X-CSRF-Token': 'test-token'
          })
        })
      )
    })
  })

  describe("addUserMessage", () => {
    it("adds user message to chat", () => {
      const content = "Hello AI"
      const chatMessages = document.getElementById('chat-messages')
      
      controller.addUserMessage(content)
      
      expect(chatMessages.innerHTML).toContain("Hello AI")
      expect(chatMessages.innerHTML).toContain("You")
      expect(chatMessages.innerHTML).toContain("bi-person")
    })

    it("handles newlines in content", () => {
      const content = "Line 1\nLine 2"
      const chatMessages = document.getElementById('chat-messages')
      
      controller.addUserMessage(content)
      
      expect(chatMessages.innerHTML).toContain("Line 1<br>Line 2")
    })
  })

  describe("typing indicator", () => {
    it("shows typing indicator", () => {
      const typingIndicator = document.getElementById('ai-typing')
      
      controller.showTypingIndicator()
      
      expect(typingIndicator.style.display).toBe('block')
    })

    it("hides typing indicator", () => {
      const typingIndicator = document.getElementById('ai-typing')
      typingIndicator.style.display = 'block'
      
      controller.hideTypingIndicator()
      
      expect(typingIndicator.style.display).toBe('none')
    })
  })

  describe("scrollToBottom", () => {
    it("scrolls chat messages to bottom", () => {
      const chatMessages = document.getElementById('chat-messages')
      const scrollSpy = jest.spyOn(chatMessages, 'scrollTop', 'set')
      
      controller.scrollToBottom()
      
      expect(scrollSpy).toHaveBeenCalled()
    })
  })

  describe("clearForm", () => {
    it("clears input and focuses", () => {
      controller.inputTarget.value = "Some text"
      const focusSpy = jest.spyOn(controller.inputTarget, 'focus')
      
      controller.clearForm()
      
      expect(controller.inputTarget.value).toBe('')
      expect(focusSpy).toHaveBeenCalled()
    })
  })
}) 