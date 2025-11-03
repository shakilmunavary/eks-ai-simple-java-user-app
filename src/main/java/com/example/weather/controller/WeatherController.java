package com.example.weather.controller;

import com.example.weather.model.WeatherData;
import com.example.weather.service.IndiaApiService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;



@RestController
@RequestMapping("/weather")
public class WeatherController {
    @Autowired
    private IndiaApiService indiaApiService;

    @GetMapping("/cities")
    public List<String> getTamilNaduCities() {
        return indiaApiService.getTamilNaduCities();
    }

    @GetMapping("/{city}")
    public WeatherData getWeather(@PathVariable String city) {
        return indiaApiService.getWeatherForCity(city);
    }
}
