package com.example.demo.controller;

import com.example.demo.model.User;
import com.example.demo.repository.UserRepository;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

@Controller
public class UserController {

  private final UserRepository repo;

  public UserController(UserRepository repo) {
    this.repo = repo;
  }

  @GetMapping("/add")
  public String showForm(Model model) {
    model.addAttribute("user", new User());
    return "add";
  }

  @PostMapping("/add")
  public String submitForm(@ModelAttribute User user) {
    repo.save(user);
    return "redirect:/list";
  }

  @GetMapping("/list")
  public String showUsers(Model model) {
    model.addAttribute("users", repo.findAll());
    return "list";
  }
}
