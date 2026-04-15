package com.service;

import com.model.GitHubRepo;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

@Service
public class GitHubService {

    @Value("${github.token}")
    private String githubToken;

    @Value("${github.username}")
    private String githubUsername;

    private final RestTemplate restTemplate = new RestTemplate();

    private static final String GITHUB_API_BASE = "https://api.github.com";

    /**
     * Get all public repositories for the configured user
     */
    public List<GitHubRepo> getUserRepos() {
        String url = GITHUB_API_BASE + "/users/" + githubUsername + "/repos?type=public&sort=updated&per_page=100";
        
        HttpHeaders headers = createHeaders();
        HttpEntity<Void> request = new HttpEntity<>(headers);

        try {
            ResponseEntity<GitHubRepo[]> response = restTemplate.exchange(
                url, HttpMethod.GET, request, GitHubRepo[].class);
            
            GitHubRepo[] repos = response.getBody();
            return repos != null ? Arrays.asList(repos) : Collections.emptyList();
        } catch (Exception e) {
            System.err.println("❌ GitHub API call failed: " + e.getMessage());
            return Collections.emptyList();
        }
    }

    /**
     * Get a specific repository by name
     */
    public GitHubRepo getRepoByName(String repoName) {
        String url = GITHUB_API_BASE + "/repos/" + githubUsername + "/" + repoName;
        
        HttpHeaders headers = createHeaders();
        HttpEntity<Void> request = new HttpEntity<>(headers);

        try {
            ResponseEntity<GitHubRepo> response = restTemplate.exchange(
                url, HttpMethod.GET, request, GitHubRepo.class);
            return response.getBody();
        } catch (Exception e) {
            System.err.println("❌ GitHub API call failed for repo " + repoName + ": " + e.getMessage());
            GitHubRepo fallback = new GitHubRepo();
            fallback.setName(repoName);
            fallback.setDescription("Unable to fetch repository details");
            return fallback;
        }
    }

    /**
     * Get list of repository names (for simple listing)
     */
    public List<String> getRepoNames() {
        return getUserRepos().stream()
                .map(GitHubRepo::getName)
                .toList();
    }

    private HttpHeaders createHeaders() {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Accept", "application/vnd.github.v3+json");
        headers.set("User-Agent", "EKS-AI-App");
        if (githubToken != null && !githubToken.isEmpty()) {
            headers.set("Authorization", "Bearer " + githubToken);
        }
        return headers;
    }
}
