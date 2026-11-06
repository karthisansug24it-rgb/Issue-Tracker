package com.devtrack.security;

import com.devtrack.model.RoleType;

import java.util.ArrayList;
import java.util.List;

/**
 * Coarse permission names sent to the client so it can show or hide navigation and
 * buttons. The API itself always re-checks through AccessService; these flags only
 * describe what each role is allowed to attempt.
 */
public final class RolePermissions {

    private RolePermissions() {}

    public static List<String> forRole(RoleType role) {
        List<String> perms = new ArrayList<>();
        switch (role) {
            case SUPER_ADMIN:
                perms.add("SYSTEM_MANAGE");
                perms.add("ADMIN_MANAGE");
                // fall through
            case ADMIN:
                perms.add("ALL_PROJECTS_VIEW");
                perms.add("DEPARTMENT_MANAGE");
                perms.add("TEAM_MANAGE");
                perms.add("USER_MANAGE");
                perms.add("USER_STATUS_MANAGE");
                perms.add("AUDIT_LOG_VIEW");
                perms.add("REPORTS_VIEW");
                // fall through
            case MANAGER:
                perms.add("PROJECT_CREATE");
                perms.add("TEAM_MANAGE_OWN");
                perms.add("ROLE_ASSIGN");
                perms.add("TEAM_REPORTS_VIEW");
                // fall through
            case TEAM_LEAD:
                perms.add("ISSUE_ASSIGN");
                perms.add("ISSUE_REVIEW");
                // fall through
            case EMPLOYEE:
                perms.add("TEAM_VIEW");
                perms.add("USER_DIRECTORY_VIEW");
                perms.add("MY_ISSUES_VIEW");
                perms.add("ISSUE_CREATE");
                perms.add("ISSUE_UPDATE_STATUS");
                perms.add("COMMENT_ADD");
                perms.add("TIME_LOG");
                break;
        }
        return perms;
    }
}
