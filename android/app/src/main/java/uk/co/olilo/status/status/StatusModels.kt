package uk.co.olilo.status.status

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class StatusPageSummary(
    val page: StatusPage,
    @SerialName("activeIncidents") val activeIncidents: List<Incident> = emptyList(),
    @SerialName("activeMaintenances") val activeMaintenances: List<Maintenance> = emptyList(),
)

@Serializable
data class StatusPage(
    val name: String,
    val url: String,
    val status: String,
)

@Serializable
data class Incident(
    val id: String,
    val name: String,
    val description: String? = null,
    val status: String,
    val impact: String? = null,
    val url: String? = null,
    val started: String? = null,
    @SerialName("updatedAt") val updatedAt: String? = null,
)

@Serializable
data class Maintenance(
    val id: String,
    val name: String,
    val status: String,
    val start: String? = null,
    val duration: Int? = null,
    val url: String? = null,
    @SerialName("updatedAt") val updatedAt: String? = null,
)

@Serializable
data class ComponentsResponse(
    val components: List<StatusComponent> = emptyList(),
)

@Serializable
data class StatusComponent(
    val id: String,
    val name: String,
    val description: String? = null,
    val status: String,
    val group: ComponentGroup? = null,
)

@Serializable
data class ComponentGroup(
    val id: String,
    val name: String,
    val description: String? = null,
)

data class StatusComponentGroup(
    val id: String,
    val name: String,
    val description: String?,
    val parent: StatusComponent?,
    val children: List<StatusComponent>,
) {
    val allComponents: List<StatusComponent> = if (parent != null) listOf(parent) + children else children
}

data class StatusNotice(
    val id: String,
    val title: String,
    val kind: NoticeKind,
    val published: String?,
    val updated: String?,
    val link: String?,
    val duration: String?,
    val affectedComponents: String?,
    val summary: String,
    val updates: List<NoticeUpdate>,
)

enum class NoticeKind(val label: String) {
    Incident("Incident"),
    Maintenance("Maintenance"),
    Notice("Notice");

    companion object {
        /** Converts a backend notice type label into a typed notice kind. */
        fun from(value: String?): NoticeKind = entries.firstOrNull { it.label == value } ?: Notice
    }
}

data class NoticeUpdate(
    val timestamp: String?,
    val status: String,
    val message: String,
)

data class StatusScreenState(
    val summary: StatusPageSummary? = null,
    val components: List<StatusComponent> = emptyList(),
    val incidents: List<Incident> = emptyList(),
    val maintenances: List<Maintenance> = emptyList(),
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
    val lastRefreshedMillis: Long? = null,
)

data class NoticesScreenState(
    val activeIncidents: List<Incident> = emptyList(),
    val activeMaintenances: List<Maintenance> = emptyList(),
    val notices: List<StatusNotice> = emptyList(),
    val selectedKind: NoticeKind? = null,
    val hideOldNotices: Boolean = true,
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
    val lastRefreshedMillis: Long? = null,
)
