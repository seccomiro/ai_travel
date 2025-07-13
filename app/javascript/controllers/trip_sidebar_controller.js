import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "segmentsCount", "statusBadge", "routeSummary", "breakdownProgress"]
  static values = {
    tripId: Number,
    lastUpdate: String
  }

  connect() {
    console.log("Trip sidebar controller connected")
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollInterval = setInterval(() => {
      this.checkForUpdates()
    }, 3000) // Check every 3 seconds for more responsive updates during breakdown
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  async checkForUpdates() {
    try {
      const response = await fetch(`/trips/${this.tripIdValue}/sidebar_content`, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const html = await response.text()
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, 'text/html')

        // Check if there's new content
        const newContent = doc.querySelector('#trip-sidebar-content')
        if (newContent) {
          this.updateSidebarContent(newContent)
        }

        // Check for breakdown progress
        this.checkBreakdownProgress(doc)
      }
    } catch (error) {
      console.error('Error checking for trip updates:', error)
    }
  }

  checkBreakdownProgress(doc) {
    const breakdownProgress = doc.querySelector('#route-breakdown-progress')
    if (breakdownProgress) {
      this.showBreakdownProgress(breakdownProgress.innerHTML)
    } else {
      this.hideBreakdownProgress()
    }
  }

  showBreakdownProgress(progressHtml) {
    if (this.hasBreakdownProgressTarget) {
      this.breakdownProgressTarget.innerHTML = progressHtml
      this.breakdownProgressTarget.classList.remove('d-none')
    } else {
      // Create progress element if it doesn't exist
      const progressElement = document.createElement('div')
      progressElement.id = 'route-breakdown-progress'
      progressElement.className = 'alert alert-info mt-3'
      progressElement.innerHTML = progressHtml
      this.contentTarget.appendChild(progressElement)
    }
  }

  hideBreakdownProgress() {
    if (this.hasBreakdownProgressTarget) {
      this.breakdownProgressTarget.classList.add('d-none')
    } else {
      const progressElement = this.contentTarget.querySelector('#route-breakdown-progress')
      if (progressElement) {
        progressElement.remove()
      }
    }
  }

  updateSidebarContent(newContent) {
    // Update the main content
    if (this.hasContentTarget) {
      this.contentTarget.innerHTML = newContent.innerHTML
    }

    // Update specific elements if they exist
    this.updateSegmentsCount(newContent)
    this.updateStatusBadge(newContent)
    this.updateRouteSummary(newContent)

    // Trigger a custom event for other controllers to listen to
    this.dispatch('updated', { detail: { tripId: this.tripIdValue } })
  }

  updateSegmentsCount(newContent) {
    const newSegmentsCount = newContent.querySelector('#trip-segments-count')
    if (newSegmentsCount && this.hasSegmentsCountTarget) {
      this.segmentsCountTarget.textContent = newSegmentsCount.textContent
    }
  }

  updateStatusBadge(newContent) {
    const newStatusBadge = newContent.querySelector('#trip-status-badge')
    if (newStatusBadge && this.hasStatusBadgeTarget) {
      this.statusBadgeTarget.innerHTML = newStatusBadge.innerHTML
    }
  }

  updateRouteSummary(newContent) {
    const newRouteSummary = newContent.querySelector('.route-summary')
    if (newRouteSummary && this.hasRouteSummaryTarget) {
      this.routeSummaryTarget.innerHTML = newRouteSummary.innerHTML
    }
  }

  // Method to force an immediate update
  refresh() {
    this.checkForUpdates()
  }

  // Method to handle real-time updates from WebSocket or SSE
  handleRealtimeUpdate(event) {
    const { tripId, updates } = event.detail

    if (tripId === this.tripIdValue) {
      // Apply specific updates based on what changed
      if (updates.route) {
        this.updateRouteInfo(updates.route)
      }

      if (updates.tripDetails) {
        this.updateTripDetails(updates.tripDetails)
      }

      if (updates.breakdownProgress) {
        this.showBreakdownProgress(updates.breakdownProgress)
      }
    }
  }

  updateRouteInfo(routeData) {
    // Update route-specific elements
    const segmentsCount = routeData.segments?.length || 0
    if (this.hasSegmentsCountTarget) {
      this.segmentsCountTarget.textContent = segmentsCount
    }

    // Update route summary if available
    if (routeData.summary && this.hasRouteSummaryTarget) {
      const summary = routeData.summary
      this.routeSummaryTarget.innerHTML = `
        <small class="text-muted d-block">
          ${summary.total_distance_km?.round()}km • ${summary.total_duration_hours?.round()}h
        </small>
      `
    }

    // Check if breakdown was applied
    if (routeData.breakdown_applied) {
      this.hideBreakdownProgress()
      this.showBreakdownComplete()
    }
  }

  showBreakdownComplete() {
    const completeMessage = `
      <div class="alert alert-success mt-3">
        <i class="fas fa-check-circle"></i>
        Route breakdown complete! All segments now fit within your driving preferences.
      </div>
    `

    if (this.hasBreakdownProgressTarget) {
      this.breakdownProgressTarget.innerHTML = completeMessage
      this.breakdownProgressTarget.classList.remove('d-none')

      // Hide the success message after 5 seconds
      setTimeout(() => {
        this.hideBreakdownProgress()
      }, 5000)
    }
  }

  updateTripDetails(tripDetails) {
    // Update trip details like title, description, etc.
    if (tripDetails.title) {
      const titleElement = this.element.querySelector('.card-title')
      if (titleElement) {
        titleElement.textContent = tripDetails.title
      }
    }

    if (tripDetails.description) {
      const descElement = this.element.querySelector('.card-text')
      if (descElement) {
        descElement.textContent = tripDetails.description
      }
    }
  }
}