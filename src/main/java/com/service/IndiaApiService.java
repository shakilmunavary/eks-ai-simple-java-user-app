package com.service;

import com.model.WeatherData;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;

@Service
public class IndiaApiService {

    @Value("${weatherapi.key}")
    private String apiKey;

    @Value("${weatherapi.url}")
    private String baseUrl;

    private final RestTemplate restTemplate = new RestTemplate();

    public List<String> getTamilNaduCities() {
        return List.of("Chennai", "Madurai", "Coimbatore", "Tiruchirappalli", "Salem");
    }

    public WeatherData getWeatherForCity(String city) {
        String url = baseUrl + "?location=" + city;
        HttpHeaders headers = new HttpHeaders();
        headers.set("x-api-key", apiKey);
        HttpEntity<Void> request = new HttpEntity<>(headers);

        try {
            ResponseEntity<WeatherData> response = restTemplate.exchange(
                url, HttpMethod.GET, request, WeatherData.class);
            return response.getBody();
        } catch (Exception e) {
            System.err.println("❌ Weather API call failed: " + e.getMessage());
            WeatherData fallback = new WeatherData();
            fallback.setLocation(city);
            fallback.setTemperature("N/A");
            fallback.setCondition("Unavailable");
            return fallback;
        }
    }
}
