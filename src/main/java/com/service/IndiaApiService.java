package com.service;

import com.model.WeatherData;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Arrays;
import java.util.List;

@Service
public class IndiaApiService {

    @Value("${indiaapi.key}")
    private String apiKey;

    private final RestTemplate restTemplate = new RestTemplate();

    public List<String> getTamilNaduCities() {
        String url = "https://api.indiaapi.in/cities?state=Tamil Nadu";
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", "Bearer " + apiKey);
        HttpEntity<Void> request = new HttpEntity<>(headers);

        ResponseEntity<String[]> response = restTemplate.exchange(
                url, HttpMethod.GET, request, String[].class);

        return Arrays.asList(response.getBody());
    }

    public WeatherData getWeatherForCity(String city) {
        String url = "https://api.indiaapi.in/weather?city=" + city;
        HttpHeaders headers = new HttpHeaders();
        headers.set("Authorization", "Bearer " + apiKey);
        HttpEntity<Void> request = new HttpEntity<>(headers);

        ResponseEntity<WeatherData> response = restTemplate.exchange(
                url, HttpMethod.GET, request, WeatherData.class);

        return response.getBody();
    }
}
