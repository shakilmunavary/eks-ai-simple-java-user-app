package com.example.demo.controller;

import com.example.demo.model.User;
import com.example.demo.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Controller
public class UserController {

  private static final Logger logger = LoggerFactory.getLogger(UserController.class);
  private final UserRepository repo;

  public UserController(UserRepository repo) {
    this.repo = repo;
  }

  @GetMapping("/add")
  public String showForm(Model model) {
    logger.info("📥 Displaying user creation form");
    model.addAttribute("user", new User());
    return "add";
  }

  @PostMapping("/add")
  public String submitForm(@ModelAttribute User user) {
    logger.info("✅ Received new user submission: name='{}'", user.getName());
    repo.save(user);
    logger.info("📦 User saved successfully. Redirecting to /list");
    return "redirect:/list";
  }

  @GetMapping("/list")
  public String showUsers(Model model) {
    logger.info("📤 Listing all users");
    List<User> users = repo.findAll();
    logger.info("📊 Total users found: {}", users.size());
    for (User user : users) {
      logger.debug("👤 User: ID={}, Name={}", user.getId(), user.getName());
    }
    model.addAttribute("users", users);
    return "list";
  }
}
