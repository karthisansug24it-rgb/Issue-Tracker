package com.devtrack.model;

public enum RoleType {
    SUPER_ADMIN(5),
    ADMIN(4),
    MANAGER(3),
    TEAM_LEAD(2),
    EMPLOYEE(1);

    private final int rank;

    RoleType(int rank) {
        this.rank = rank;
    }

    public int getRank() { return rank; }

    public boolean isAtLeast(RoleType other) {
        return rank >= other.rank;
    }
}
