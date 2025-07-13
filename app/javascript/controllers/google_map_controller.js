import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"

export default class extends Controller {
  static values = {
    apiKey: String,
    route: Object,
    routeId: String,
  }

  connect() {
    console.log("🗺️ Google Map Controller connected.");
    this.lastProcessedRouteId = null
    this.initMap()
  }

  routeValueChanged() {
    console.log("🗺️ Route data changed:", this.routeValue);
    if (this.routeIdValue && this.routeIdValue !== this.lastProcessedRouteId) {
      console.log("🗺️ New route ID detected. Re-initializing map.");
      this.initMap();
    }
  }

  async initMap() {
    console.log("🗺️ initMap called.");
    if (!this.apiKeyValue) {
      console.error("Google Maps API Key is missing.");
      this.element.innerHTML = '<div class="alert alert-danger">API key is missing.</div>';
      return;
    }

    const loader = new Loader({
      apiKey: this.apiKeyValue,
      version: "weekly",
    });

    try {
      console.log("🗺️ Loading Google Maps library...");
      const { Map } = await loader.importLibrary("maps");

      this.map = new Map(this.element, {
        center: { lat: -34.397, lng: 150.644 },
        zoom: 4,
        mapId: "TRIPYO_MAP"
      });
      console.log("🗺️ Map initialized.");


      if (this.routeValue && Object.keys(this.routeValue).length > 0) {
        console.log("🗺️ Drawing route with data:", this.routeValue);
        this.lastProcessedRouteId = this.routeIdValue;
        this.drawRoute(this.routeValue);
      } else {
        console.log("🗺️ No route data to draw on init.");
      }
    } catch (e) {
      console.error("Error loading Google Maps or drawing route: ", e);
      this.element.innerHTML = '<div class="alert alert-danger">Could not load map. Please check the API key and console for errors.</div>'
    }
  }

  getGoogleTravelMode(mode) {
    const saneMode = (mode || 'driving').toLowerCase();
    switch (saneMode) {
      case 'car':
      case 'driving':
        return google.maps.TravelMode.DRIVING;
      case 'walking':
        return google.maps.TravelMode.WALKING;
      case 'bicycling':
        return google.maps.TravelMode.BICYCLING;
      case 'transit':
        return google.maps.TravelMode.TRANSIT;
      default:
        console.warn(`Unknown travel mode '${mode}', defaulting to DRIVING.`);
        return google.maps.TravelMode.DRIVING;
    }
  }

  async drawRoute(routeData) {
    if (!routeData.destinations || routeData.destinations.length < 2) {
      console.log("🗺️ Insufficient destination data to draw route.");
      return;
    };

    console.log("🗺️ Importing Routes library...");
    const { DirectionsService, DirectionsRenderer } = await google.maps.importLibrary("routes");

    const directionsService = new google.maps.DirectionsService();
    const directionsRenderer = new google.maps.DirectionsRenderer();
    directionsRenderer.setMap(this.map);

    const travelMode = this.getGoogleTravelMode(routeData.mode);

    const request = {
      origin: routeData.destinations[0],
      destination: routeData.destinations[routeData.destinations.length - 1],
      waypoints: routeData.destinations.slice(1, -1).map(location => ({ location, stopover: true })),
      travelMode: travelMode,
    };

    try {
      console.log("🗺️ Requesting directions:", request);
      const results = await directionsService.route(request);
      console.log("🗺️ Directions received:", results);
      directionsRenderer.setDirections(results);

      // This is a common fix for the gray map problem.
      // It tells the map to re-check its size and redraw itself.
      google.maps.event.trigger(this.map, "resize");
      if (results.routes?.[0]?.bounds) {
        this.map.fitBounds(results.routes[0].bounds);
      }
      console.log("🗺️ Route rendered and map resized.");

    } catch (e) {
      console.error(`Directions request failed: ${e}`);
    }
  }
} 