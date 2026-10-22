package com.devtrack;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * End-to-end checks of the role rules against the demo organisation:
 *  Super Admin, Divya (ADMIN), Arun (MANAGER, owns WEB/MOB/PAY), Suresh (TEAM_LEAD, TECH_LEAD on WEB/MOB),
 *  Vijay (TEAM_LEAD, TESTER on WEB/MOB), Karthi (EMPLOYEE on WEB/MOB), Priya (EMPLOYEE on WEB/PAY).
 * Each test runs in a transaction that is rolled back.
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:devtrack-test;DB_CLOSE_DELAY=-1;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH",
        "devtrack.jwt.secret=test-secret-test-secret-test-secret-0123456789",
        "devtrack.seed.demo-data=true",
        "devtrack.bootstrap.admin-password="
})
@ActiveProfiles("default")
@AutoConfigureMockMvc
@Transactional
class AccessControlIntegrationTest {

    static final String SUPER = "superadmin@devtrack.com";
    static final String ADMIN = "admin@devtrack.com";
    static final String ARUN = "arun.manager@devtrack.com";
    static final String SURESH = "suresh.lead@devtrack.com";
    static final String KARTHI = "karthi.dev@devtrack.com";
    static final String PRIYA = "priya.dev@devtrack.com";

    @Autowired
    MockMvc mvc;

    // ------------------------------------------------------------------ helpers

    String token(String email) throws Exception {
        String password = "qwerty123";
        String body = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"" + password + "\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.token");
    }

    ResultActions as(String email, MockHttpServletRequestBuilder request) throws Exception {
        return mvc.perform(request.header("Authorization", "Bearer " + token(email)));
    }

    ResultActions asJson(String email, MockHttpServletRequestBuilder request, String json) throws Exception {
        return as(email, request.contentType(MediaType.APPLICATION_JSON).content(json));
    }

    long issueId(String key) throws Exception {
        String body = as(SUPER, get("/api/v1/issues").param("search", key)).andReturn().getResponse().getContentAsString();
        List<Integer> ids = JsonPath.read(body, "$[?(@.issueKey == '" + key + "')].id");
        return ids.get(0);
    }

    long userId(String email) throws Exception {
        String body = as(SUPER, get("/api/v1/users")).andReturn().getResponse().getContentAsString();
        List<Integer> ids = JsonPath.read(body, "$[?(@.email == '" + email + "')].id");
        return ids.get(0);
    }

    long projectId(String key) throws Exception {
        String body = as(SUPER, get("/api/v1/projects")).andReturn().getResponse().getContentAsString();
        List<Integer> ids = JsonPath.read(body, "$[?(@.projectKey == '" + key + "')].id");
        return ids.get(0);
    }

    // ---------------------------------------------------------- authentication

    @Test
    void wrongPasswordReturns401WithMessage() throws Exception {
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + KARTHI + "\",\"password\":\"wrong-password\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").value("Invalid email or password"));
    }

    @Test
    void missingTokenReturns401() throws Exception {
        mvc.perform(get("/api/v1/issues"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message", containsString("sign in")));
    }

    @Test
    void departmentListIsPublicButChangesAreNot() throws Exception {
        mvc.perform(get("/api/v1/departments")).andExpect(status().isOk());
        mvc.perform(post("/api/v1/departments").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"X\",\"code\":\"XX\"}"))
                .andExpect(status().isUnauthorized());
        asJson(ARUN, post("/api/v1/departments"), "{\"name\":\"X\",\"code\":\"XX\"}")
                .andExpect(status().isForbidden());
    }

    @Test
    void meReturnsPermissions() throws Exception {
        as(KARTHI, get("/api/v1/auth/me"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("EMPLOYEE"))
                .andExpect(jsonPath("$.permissions", hasItem("ISSUE_CREATE")))
                .andExpect(jsonPath("$.permissions", not(hasItem("ISSUE_ASSIGN"))));
    }

    @Test
    void registrationAlwaysCreatesEmployeeAndValidatesPassword() throws Exception {
        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fullName\":\"New Person\",\"email\":\"new@devtrack.com\",\"password\":\"long-enough-1\","
                                + "\"role\":\"SUPER_ADMIN\",\"department\":\"qa\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("EMPLOYEE"))
                .andExpect(jsonPath("$.department").value("Quality Assurance"))
                .andExpect(jsonPath("$.departmentId").isNumber());

        mvc.perform(post("/api/v1/auth/register").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fullName\":\"Short\",\"email\":\"short@devtrack.com\",\"password\":\"abc\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("at least 8")));
    }

    // ---------------------------------------------------------------- visibility

    @Test
    void employeeSeesOnlyTheirProjectsAndIssues() throws Exception {
        as(PRIYA, get("/api/v1/projects"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].projectKey", containsInAnyOrder("WEB", "PAY")));

        as(PRIYA, get("/api/v1/issues"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].projectKey", everyItem(in(List.of("WEB", "PAY")))));

        long mobIssue = issueId("MOB-101");
        as(PRIYA, get("/api/v1/issues/" + mobIssue)).andExpect(status().isForbidden());
        as(PRIYA, get("/api/v1/issues/" + mobIssue + "/comments")).andExpect(status().isForbidden());
    }

    @Test
    void adminSeesEverything() throws Exception {
        as(ADMIN, get("/api/v1/projects"))
                .andExpect(jsonPath("$[*].projectKey", containsInAnyOrder("WEB", "MOB", "PAY")));
    }

    @Test
    void employeesCannotListTheStaffDirectory() throws Exception {
        as(KARTHI, get("/api/v1/users")).andExpect(status().isForbidden());
        as(SURESH, get("/api/v1/users")).andExpect(status().isOk());
        // ...but can see the members of their own project for assignment
        as(KARTHI, get("/api/v1/projects/" + projectId("WEB") + "/members")).andExpect(status().isOk());
        as(KARTHI, get("/api/v1/projects/" + projectId("PAY") + "/members")).andExpect(status().isForbidden());
    }

    // ------------------------------------------------------------ issue workflow

    @Test
    void assigneeCanStartWorkButCannotApproveOwnWork() throws Exception {
        long web101 = issueId("WEB-101"); // ASSIGNED to Karthi
        asJson(KARTHI, patch("/api/v1/issues/" + web101 + "/status"), "{\"status\":\"IN_PROGRESS\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.allowedTransitions", hasItem("IN_REVIEW")))
                .andExpect(jsonPath("$.allowedTransitions", not(hasItem("RESOLVED"))));

        long mob101 = issueId("MOB-101"); // IN_REVIEW, assigned to Karthi
        asJson(KARTHI, patch("/api/v1/issues/" + mob101 + "/status"), "{\"status\":\"RESOLVED\"}")
                .andExpect(status().isForbidden());
        asJson(SURESH, patch("/api/v1/issues/" + mob101 + "/status"), "{\"status\":\"RESOLVED\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resolvedAt").isNotEmpty());
    }

    @Test
    void invalidTransitionsAreRejected() throws Exception {
        long web101 = issueId("WEB-101"); // ASSIGNED
        asJson(ARUN, patch("/api/v1/issues/" + web101 + "/status"), "{\"status\":\"RESOLVED\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("cannot move")));
        // OPEN means unowned: an assigned issue must be unassigned instead
        asJson(KARTHI, patch("/api/v1/issues/" + web101 + "/status"), "{\"status\":\"OPEN\"}")
                .andExpect(status().isBadRequest());
        as(KARTHI, get("/api/v1/issues/" + web101))
                .andExpect(jsonPath("$.allowedTransitions", containsInAnyOrder("IN_PROGRESS", "BLOCKED")));
    }

    @Test
    void reopeningClearsResolvedAt() throws Exception {
        long web103 = issueId("WEB-103"); // RESOLVED
        asJson(ARUN, patch("/api/v1/issues/" + web103 + "/status"), "{\"status\":\"REOPENED\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.resolvedAt").doesNotExist());
    }

    @Test
    void employeeCannotChangeSomeoneElsesIssue() throws Exception {
        long web101 = issueId("WEB-101"); // Karthi's
        asJson(PRIYA, patch("/api/v1/issues/" + web101 + "/status"), "{\"status\":\"IN_PROGRESS\"}")
                .andExpect(status().isForbidden());
        asJson(PRIYA, patch("/api/v1/issues/" + web101 + "/assignee"), "{\"assigneeId\":" + userId(PRIYA) + "}")
                .andExpect(status().isForbidden());
    }

    @Test
    void assigneeMustBeAProjectMemberAndUnassignResetsStatus() throws Exception {
        long pay101 = issueId("PAY-101"); // PAY: Arun + Priya only
        asJson(ARUN, patch("/api/v1/issues/" + pay101 + "/assignee"), "{\"assigneeId\":" + userId(KARTHI) + "}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("not a member")));

        asJson(ARUN, patch("/api/v1/issues/" + pay101 + "/assignee"), "{\"assigneeId\":null}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.assigneeId").doesNotExist())
                .andExpect(jsonPath("$.status").value("OPEN"));
    }

    @Test
    void employeeCanReportButOnlySelfAssign() throws Exception {
        long web = projectId("WEB");
        asJson(PRIYA, post("/api/v1/issues"), "{\"projectId\":" + web + ",\"title\":\"Typo\",\"type\":\"BUG\",\"priority\":\"LOW\","
                + "\"assigneeId\":" + userId(KARTHI) + "}")
                .andExpect(status().isForbidden());
        asJson(PRIYA, post("/api/v1/issues"), "{\"projectId\":" + web + ",\"title\":\"Typo\",\"type\":\"BUG\",\"priority\":\"LOW\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("OPEN"));
        asJson(PRIYA, post("/api/v1/issues"), "{\"projectId\":" + projectId("MOB") + ",\"title\":\"x\",\"type\":\"BUG\",\"priority\":\"LOW\"}")
                .andExpect(status().isForbidden());
    }

    @Test
    void issueKeysAreSequentialAndUnique() throws Exception {
        long web = projectId("WEB");
        String json = "{\"projectId\":" + web + ",\"title\":\"Seq\",\"type\":\"TASK\",\"priority\":\"LOW\"}";
        asJson(ARUN, post("/api/v1/issues"), json).andExpect(jsonPath("$.issueKey").value("WEB-104"));
        asJson(ARUN, post("/api/v1/issues"), json).andExpect(jsonPath("$.issueKey").value("WEB-105"));
    }

    @Test
    void timeAndCommentInputIsValidated() throws Exception {
        long web101 = issueId("WEB-101");
        asJson(KARTHI, post("/api/v1/issues/" + web101 + "/time-entries"), "{\"durationMinutes\":-5}")
                .andExpect(status().isBadRequest());
        asJson(KARTHI, post("/api/v1/issues/" + web101 + "/time-entries"), "{\"durationMinutes\":45,\"workDescription\":\"Debugging\"}")
                .andExpect(status().isOk());
        asJson(PRIYA, post("/api/v1/issues/" + web101 + "/time-entries"), "{\"durationMinutes\":45}")
                .andExpect(status().isForbidden());
        asJson(KARTHI, post("/api/v1/issues/" + web101 + "/comments"), "{\"commentText\":\"  \"}")
                .andExpect(status().isBadRequest());
    }

    // -------------------------------------------------------------- user admin

    @Test
    void roleHierarchyIsEnforced() throws Exception {
        long superId = userId(SUPER);
        long adminId = userId(ADMIN);
        long karthiId = userId(KARTHI);

        as(ADMIN, patch("/api/v1/users/" + superId + "/status")).andExpect(status().isForbidden());
        asJson(ADMIN, patch("/api/v1/users/" + karthiId + "/role"), "{\"role\":\"ADMIN\"}").andExpect(status().isForbidden());
        asJson(ADMIN, patch("/api/v1/users/" + karthiId + "/role"), "{\"role\":\"MANAGER\"}").andExpect(status().isOk());
        asJson(ARUN, patch("/api/v1/users/" + adminId + "/role"), "{\"role\":\"EMPLOYEE\"}").andExpect(status().isForbidden());
        asJson(SUPER, patch("/api/v1/users/" + superId + "/role"), "{\"role\":\"EMPLOYEE\"}").andExpect(status().isForbidden());
        as(SUPER, patch("/api/v1/users/" + superId + "/status")).andExpect(status().isForbidden());
        as(SUPER, patch("/api/v1/users/" + adminId + "/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active").value(false));
    }

    @Test
    void disabledUserCannotSignIn() throws Exception {
        as(SUPER, patch("/api/v1/users/" + userId(PRIYA) + "/status")).andExpect(status().isOk());
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + PRIYA + "\",\"password\":\"qwerty123\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message", containsString("disabled")));
    }

    // ------------------------------------------------------- projects & teams

    @Test
    void createProjectIgnoresClientSuppliedIdAndOwner() throws Exception {
        long web = projectId("WEB");
        asJson(ARUN, post("/api/v1/projects"), "{\"id\":" + web + ",\"projectKey\":\"NEW\",\"name\":\"New\"}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id", not(equalTo((int) web))))
                .andExpect(jsonPath("$.canManage").value(true));
        as(ARUN, get("/api/v1/projects/" + web)).andExpect(jsonPath("$.projectKey").value("WEB"));

        asJson(ARUN, post("/api/v1/projects"), "{\"projectKey\":\"OTH\",\"name\":\"Other\",\"ownerId\":" + userId(SUPER) + "}")
                .andExpect(status().isForbidden());
    }

    @Test
    void onlyProjectManagersManageMembers() throws Exception {
        long pay = projectId("PAY");
        asJson(SURESH, post("/api/v1/projects/" + pay + "/members"), "{\"userId\":" + userId(KARTHI) + "}")
                .andExpect(status().isForbidden());
        asJson(ARUN, post("/api/v1/projects/" + pay + "/members"), "{\"userId\":" + userId(KARTHI) + ",\"projectRole\":\"DEVELOPER\"}")
                .andExpect(status().isOk());
        as(ARUN, delete("/api/v1/projects/" + pay + "/members/" + userId(ARUN)))
                .andExpect(status().isBadRequest()); // owner cannot be removed
    }

    @Test
    void notificationsBelongToTheirRecipient() throws Exception {
        String body = as(KARTHI, get("/api/v1/notifications")).andReturn().getResponse().getContentAsString();
        Integer id = JsonPath.read(body, "$[0].id");
        as(PRIYA, patch("/api/v1/notifications/" + id + "/read")).andExpect(status().isNotFound());
        as(KARTHI, patch("/api/v1/notifications/" + id + "/read")).andExpect(status().isOk());
    }

    @Test
    void managersOnlyCreateTeamsTheyManage() throws Exception {
        String depts = as(ARUN, get("/api/v1/departments")).andReturn().getResponse().getContentAsString();
        Integer engId = ((List<Integer>) JsonPath.read(depts, "$[?(@.code == 'ENG')].id")).get(0);

        asJson(ARUN, post("/api/v1/teams"), "{\"name\":\"X\",\"departmentId\":" + engId + ",\"managerId\":" + userId(SUPER) + "}")
                .andExpect(status().isForbidden());
        asJson(ARUN, post("/api/v1/teams"), "{\"name\":\"X\",\"departmentId\":" + engId + ",\"teamLeadId\":" + userId(KARTHI) + "}")
                .andExpect(status().isBadRequest()); // employees cannot be team leads
        asJson(ARUN, post("/api/v1/teams"), "{\"name\":\"X\",\"departmentId\":" + engId + ",\"teamLeadId\":" + userId(SURESH) + "}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.managerName").value("Arun Kumar"));
        as(KARTHI, get("/api/v1/teams")).andExpect(status().isForbidden());
    }

    @Test
    void departmentInUseCannotBeDeleted() throws Exception {
        String depts = as(ADMIN, get("/api/v1/departments")).andReturn().getResponse().getContentAsString();
        Integer engId = ((List<Integer>) JsonPath.read(depts, "$[?(@.code == 'ENG')].id")).get(0);
        as(ADMIN, delete("/api/v1/departments/" + engId))
                .andExpect(status().isConflict());
    }

    @Test
    void dashboardIsScopedForEmployees() throws Exception {
        String admin = as(ADMIN, get("/api/v1/dashboard/metrics")).andReturn().getResponse().getContentAsString();
        String priya = as(PRIYA, get("/api/v1/dashboard/metrics")).andReturn().getResponse().getContentAsString();
        int adminTotal = JsonPath.read(admin, "$.totalIssues");
        int priyaTotal = JsonPath.read(priya, "$.totalIssues");
        assertThat(priyaTotal).isLessThan(adminTotal);
        assertThat((Integer) JsonPath.read(priya, "$.totalProjects")).isEqualTo(2);
    }
}
