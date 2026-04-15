package com.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;

@JsonIgnoreProperties(ignoreUnknown = true)
public class GitHubRepo {
    private Long id;
    private String name;
    
    @JsonProperty("full_name")
    private String fullName;
    
    private String description;
    
    @JsonProperty("html_url")
    private String htmlUrl;
    
    @JsonProperty("clone_url")
    private String cloneUrl;
    
    private String language;
    
    @JsonProperty("stargazers_count")
    private int stars;
    
    @JsonProperty("forks_count")
    private int forks;
    
    @JsonProperty("open_issues_count")
    private int openIssues;
    
    @JsonProperty("private")
    private boolean isPrivate;

    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getHtmlUrl() { return htmlUrl; }
    public void setHtmlUrl(String htmlUrl) { this.htmlUrl = htmlUrl; }

    public String getCloneUrl() { return cloneUrl; }
    public void setCloneUrl(String cloneUrl) { this.cloneUrl = cloneUrl; }

    public String getLanguage() { return language; }
    public void setLanguage(String language) { this.language = language; }

    public int getStars() { return stars; }
    public void setStars(int stars) { this.stars = stars; }

    public int getForks() { return forks; }
    public void setForks(int forks) { this.forks = forks; }

    public int getOpenIssues() { return openIssues; }
    public void setOpenIssues(int openIssues) { this.openIssues = openIssues; }

    public boolean isPrivate() { return isPrivate; }
    public void setPrivate(boolean isPrivate) { this.isPrivate = isPrivate; }
}
