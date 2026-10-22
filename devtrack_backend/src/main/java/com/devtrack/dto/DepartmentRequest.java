package com.devtrack.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public class DepartmentRequest {
    @NotBlank(message = "Department name is required")
    @Size(max = 100, message = "Department name must be at most 100 characters")
    private String name;

    @NotBlank(message = "Department code is required")
    @Pattern(regexp = "^[A-Za-z0-9_-]{2,10}$", message = "Department code must be 2-10 letters, digits, '-' or '_'")
    private String code;

    @Size(max = 255, message = "Description must be at most 255 characters")
    private String description;

    private Boolean active;

    public DepartmentRequest() {}

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Boolean getActive() { return active; }
    public void setActive(Boolean active) { this.active = active; }
}
