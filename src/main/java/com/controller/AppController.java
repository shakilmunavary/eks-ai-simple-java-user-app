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

    // User endpoints
    @GetMapping("/list")
    public String showUsers(Model model) {
        List<User> users = userRepository.findAll();
        model.addAttribute("users", users);
        return "user-list";
    }

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

    // Weather endpoints
    @ResponseBody
    @GetMapping("/weather/cities")
    public List<String> getTamilNaduCities() {
        return indiaApiService.getTamilNaduCities();
    }

    @ResponseBody
    @GetMapping("/weather/{location}")
    public WeatherData getWeather(@PathVariable String location) {
        return indiaApiService.getWeatherForCity(location);
    }

    @ResponseBody
    @GetMapping("/weather/ping")
    public String ping() {
        return "Weather module is alive";
    }
}
