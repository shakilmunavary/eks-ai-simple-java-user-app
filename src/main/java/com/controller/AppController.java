package com.controller;

import com.model.User;
import com.model.GitHubRepo;
import com.repository.UserRepository;
import com.service.GitHubService;
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
    private GitHubService gitHubService;

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

    // GitHub repos list (HTML view)
    @GetMapping("/github/repos/view")
    public String showRepoList(Model model) {
        List<GitHubRepo> repos = gitHubService.getUserRepos();
        model.addAttribute("repos", repos);
        return "github-repos";
    }

    // GitHub repo details (JSON)
    @ResponseBody
    @GetMapping("/github/repo/{repoName}")
    public GitHubRepo getRepo(@PathVariable String repoName) {
        return gitHubService.getRepoByName(repoName);
    }

    // GitHub repo details (HTML view)
    @GetMapping("/github/repo/view/{repoName}")
    public String showRepoHtml(@PathVariable("repoName") String repoName, Model model) {
        GitHubRepo repo = gitHubService.getRepoByName(repoName);
        model.addAttribute("repo", repo);
        model.addAttribute("repoName", repoName);
        return "github-repo-view";
    }

    // Raw repo list (JSON)
    @ResponseBody
    @GetMapping("/github/repos")
    public List<GitHubRepo> getAllRepos() {
        return gitHubService.getUserRepos();
    }

    // Health check
    @ResponseBody
    @GetMapping("/github/ping")
    public String ping() {
        return "GitHub module is alive";
    }
}
