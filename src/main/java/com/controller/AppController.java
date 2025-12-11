package com.controller;

import com.model.User;
import com.model.WeatherData;
import com.repository.UserRepository;
import com.service.IndiaApiService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Controller
public class AppController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private IndiaApiService indiaApiService;

    // Home page
    @GetMapping("/")
    public String home(Model model) {
        return "home";
    }

    // Add user
    @GetMapping("/add")
    public String showAddForm(Model model) {
        model.addAttribute("user", new User());
        return "user-add";
    }

    @PostMapping("/add")
    public String addUser(@ModelAttribute User user) {
        userRepository.save(user);
        return "redirect:/list";
    }

    // List users
    @GetMapping("/list")
    public String showUsers(Model model) {
        List<User> users = userRepository.findAll();
        model.addAttribute("users", users);
        return "user-list";
    }

    // Weather cities list (HTML view)
    @GetMapping("/weather/cities/view")
    public String showCityLinks(Model model) {
        List<String> cities = indiaApiService.getTamilNaduCities();
        model.addAttribute("cities", cities);
        return "weather-cities";
    }

    // Weather data for a city (JSON)
    @ResponseBody
    @GetMapping("/weather/{location}")
    public WeatherData getWeather(@PathVariable String location) {
        return indiaApiService.getWeatherForCity(location);
    }

    // Weather data for a city (HTML view)
    @GetMapping("/weather/view/{location}")
    public String showWeatherHtml(@PathVariable("location") String location, Model model) {
        WeatherData data = indiaApiService.getWeatherForCity(location);

        // Add both weather data and raw city name from URL
        model.addAttribute("weather", data);
        model.addAttribute("cityName", location);

        return "weather-view";
    }

    // Raw city list (JSON)
    @ResponseBody
    @GetMapping("/weather/cities")
    public List<String> getTamilNaduCities() {
        return indiaApiService.getTamilNaduCities();
    }

    // Health check
    @ResponseBody
    @GetMapping("/weather/ping")
    public String ping() {
        return "Weather module is alive";
    }
}
