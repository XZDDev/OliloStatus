package uk.co.olilo.status.main

import android.Manifest
import android.annotation.SuppressLint
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Process
import android.webkit.CookieManager
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.ReportProblem
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Terminal
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Switch
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.temporal.ChronoUnit
import kotlin.system.exitProcess
import uk.co.olilo.status.status.Incident
import uk.co.olilo.status.status.Maintenance
import uk.co.olilo.status.status.NoticeKind
import uk.co.olilo.status.R
import uk.co.olilo.status.status.StatusComponent
import uk.co.olilo.status.status.StatusComponentGroup
import uk.co.olilo.status.status.StatusNotice
import uk.co.olilo.status.status.StatusPageSummary
import uk.co.olilo.status.status.StatusScreenState
import uk.co.olilo.status.status.formatRemoteDate
import uk.co.olilo.status.status.formatTime
import uk.co.olilo.status.status.groupedComponents
import uk.co.olilo.status.notifications.NotificationPreferences
import uk.co.olilo.status.notifications.NotificationStore
import uk.co.olilo.status.notifications.OliloNotifications
import uk.co.olilo.status.status.OliloTheme
import uk.co.olilo.status.status.readableStatus
import uk.co.olilo.status.status.loadOliloTheme
import uk.co.olilo.status.status.saveOliloTheme
import uk.co.olilo.status.status.statusColor
import uk.co.olilo.status.status.statusSeverity
import uk.co.olilo.status.widget.OliloNoticesWidgetProvider
import uk.co.olilo.status.widget.OliloStatusWidgetProvider
import androidx.core.content.edit
import androidx.core.net.toUri

class MainActivity : ComponentActivity() {
    private var launchRequest by mutableStateOf(LaunchRequest(Route.Status.path, 0))

    /** Creates the Compose root and routes notification launches to the requested tab. */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        launchRequest = launchRequest.copy(route = intent.requestedRoute())
        setContent {
            var selectedTheme by remember { mutableStateOf(loadOliloTheme(this@MainActivity)) }
            OliloStatusTheme(selectedTheme) {
                OliloApp(
                    launchRequest = launchRequest,
                    onThemeSelected = { theme ->
                        val didSave = saveOliloTheme(this@MainActivity, theme)
                        if (didSave) {
                            selectedTheme = theme
                            refreshOliloWidgets(this@MainActivity)
                        }
                        didSave
                    },
                )
            }
        }
    }

    /** Handles notification taps delivered to an already running activity. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        launchRequest = LaunchRequest(intent.requestedRoute(), launchRequest.nonce + 1)
    }

    companion object {
        const val NOTIFICATION_TARGET_TAB = "uk.co.olilo.status.NOTIFICATION_TARGET_TAB"
        const val TAB_NOTICES = "notices"
    }
}

private data class LaunchRequest(val route: String, val nonce: Int)

private val LocalOliloTheme = staticCompositionLocalOf { OliloTheme.OliloPurple }

private enum class Route(val path: String, val label: String, val icon: ImageVector) {
    Status("status", "Status", Icons.Filled.Dashboard),
    Notices("notices", "Notices", Icons.Filled.Notifications),
    Settings("settings", "Settings", Icons.Filled.Settings),
}

/** Maps an optional launch intent to the first route the app should show. */
private fun Intent?.requestedRoute(): String = when (this?.getStringExtra(MainActivity.NOTIFICATION_TARGET_TAB)) {
    MainActivity.TAB_NOTICES -> Route.Notices.path
    else -> Route.Status.path
}

/** Hosts the tab navigation shell and applies launch requests from notifications. */
@Composable
private fun OliloApp(
    launchRequest: LaunchRequest,
    onThemeSelected: (OliloTheme) -> Boolean,
) {
    val context = LocalContext.current
    val navController = rememberNavController()
    val backStack by navController.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    // Keep onboarding presentation at the app shell so first launch and Settings replay share one flow.
    var hasCompletedOnboarding by remember { mutableStateOf(loadHasCompletedOnboarding(context)) }
    var showOnboarding by remember { mutableStateOf(!hasCompletedOnboarding) }

    /** Marks onboarding as complete and hides the tutorial. */
    fun completeOnboarding() {
        hasCompletedOnboarding = true
        showOnboarding = false
        saveHasCompletedOnboarding(context, true)
    }

    LaunchedEffect(launchRequest) {
        if (currentRoute != launchRequest.route) {
            navController.navigate(launchRequest.route) {
                popUpTo(Route.Status.path)
                launchSingleTop = true
            }
        }
    }

    GradientBackground {
        Scaffold(
            containerColor = Color.Transparent,
            contentColor = Color.White,
            contentWindowInsets = WindowInsets(0.dp),
            bottomBar = {
                if (Route.entries.any { it.path == currentRoute }) {
                    NavigationBar(containerColor = themedNavigationBarColor()) {
                        Route.entries.forEach { route ->
                            NavigationBarItem(
                                selected = currentRoute == route.path,
                                onClick = {
                                    navController.navigate(route.path) {
                                        popUpTo(Route.Status.path)
                                        launchSingleTop = true
                                    }
                                },
                                icon = { Icon(route.icon, contentDescription = route.label) },
                                label = { Text(route.label) },
                            )
                        }
                    }
                }
            },
        ) { padding ->
            NavHost(
                navController = navController,
                startDestination = Route.Status.path,
                modifier = Modifier.padding(padding),
            ) {
                composable(Route.Status.path) { StatusScreen(navController) }
                composable(Route.Notices.path) { NoticesScreen(navController) }
                composable(Route.Settings.path) { SettingsScreen(navController) }
                composable("notification-settings") { NotificationSettingsScreen(navController) }
                composable("appearance-settings") { AppearanceSettingsScreen(navController, onThemeSelected) }
                composable("credits") { CreditsPage(navController) }
                composable("contact") { ContactUsPage(navController) }
                composable("web/{title}/{url}") { entry ->
                    WebPage(
                        navController = navController,
                        title = Uri.decode(entry.arguments?.getString("title").orEmpty()),
                        url = Uri.decode(entry.arguments?.getString("url").orEmpty()),
                    )
                }
                composable("iframe/{title}/{url}") { entry ->
                    IframePage(
                        navController = navController,
                        title = Uri.decode(entry.arguments?.getString("title").orEmpty()),
                        url = Uri.decode(entry.arguments?.getString("url").orEmpty()),
                    )
                }
            }
        }

        // Draw onboarding above the tab scaffold so it behaves like a full-screen modal.
        if (showOnboarding) {
            OnboardingScreen(
                allowBackDismiss = hasCompletedOnboarding,
                onComplete = ::completeOnboarding,
                onDismiss = { showOnboarding = false },
            )
        }
    }
}

/** Navigates to the in-app WebView route with URL-safe arguments. */
private fun NavHostController.openWeb(title: String, url: String) {
    navigate("web/${Uri.encode(title)}/${Uri.encode(url)}")
}

private fun NavHostController.openIframe(title: String, url: String) {
    navigate("iframe/${Uri.encode(title)}/${Uri.encode(url)}")
}

// Stored separately from component preferences so onboarding can be reset independently if needed.
private const val ONBOARDING_PREFERENCES_NAME = "onboarding_preferences"
private const val HAS_COMPLETED_ONBOARDING_KEY = "has_completed_onboarding"

/** Loads whether the first-run onboarding tutorial has been completed. */
private fun loadHasCompletedOnboarding(context: Context): Boolean =
    context.getSharedPreferences(ONBOARDING_PREFERENCES_NAME, Context.MODE_PRIVATE)
        .getBoolean(HAS_COMPLETED_ONBOARDING_KEY, false)

/** Persists whether the first-run onboarding tutorial has been completed. */
private fun saveHasCompletedOnboarding(context: Context, hasCompleted: Boolean) {
    context.getSharedPreferences(ONBOARDING_PREFERENCES_NAME, Context.MODE_PRIVATE)
        .edit {
            putBoolean(HAS_COMPLETED_ONBOARDING_KEY, hasCompleted)
        }
}

/** Closes the task and terminates the process after a setting requires a cold start. */
private fun closeAppForRestart(context: Context) {
    (context as? ComponentActivity)?.finishAffinity()
    Process.killProcess(Process.myPid())
    exitProcess(0)
}

/** Forces existing widgets to redraw after theme preferences change. */
private fun refreshOliloWidgets(context: Context) {
    val appWidgetManager = AppWidgetManager.getInstance(context)
    appWidgetManager.getAppWidgetIds(ComponentName(context, OliloStatusWidgetProvider::class.java))
        .forEach { appWidgetId ->
            OliloStatusWidgetProvider.refreshWidget(context, appWidgetManager, appWidgetId)
        }
    appWidgetManager.getAppWidgetIds(ComponentName(context, OliloNoticesWidgetProvider::class.java))
        .forEach { appWidgetId ->
            OliloNoticesWidgetProvider.refreshWidget(context, appWidgetManager, appWidgetId)
        }
}

/** Describes one onboarding step and the short checklist shown on that page. */
private data class OnboardingPage(
    val title: String,
    val message: String,
    val icon: ImageVector,
    val highlights: List<String>,
)

// Ordered to match the primary app tabs, then the Settings support affordances.
private val onboardingPages = listOf(
    OnboardingPage(
        title = "Track service health",
        message = "The Status tab gives you a live view of Olilo services, affected components, active incidents, and scheduled maintenance.",
        icon = Icons.Filled.Dashboard,
        highlights = listOf(
            "Refresh status whenever you need the latest update",
            "Open dashboard, portal, terminal, and wiki links from one place",
            "Choose which components are shown on your status screen",
        ),
    ),
    OnboardingPage(
        title = "Follow notices",
        message = "The Notices tab keeps current and historical incident and maintenance updates together so you can review what changed and when.",
        icon = Icons.Filled.Notifications,
        highlights = listOf(
            "Filter notice history by incident or maintenance",
            "Open linked incident and maintenance reports",
            "See current notices before older history",
        ),
    ),
    OnboardingPage(
        title = "Control notifications",
        message = "Use Settings to decide which status updates you want delivered to this device.",
        icon = Icons.Filled.Notifications,
        highlights = listOf(
            "Enable alerts for incidents, maintenance, and component changes",
            "Choose specific networks for all status alerts",
            "Update your preferences at any time",
        ),
    ),
    OnboardingPage(
        title = "Get help quickly",
        message = "Settings also includes support, compliance, version, and contributor information when you need it.",
        icon = Icons.Filled.Settings,
        highlights = listOf(
            "Contact Olilo support from inside the app",
            "Report a problem using the project board link",
            "Restart this tutorial from Settings whenever you want",
        ),
    ),
)

/** Displays the first-run onboarding tutorial and Settings-triggered replay flow. */
@Composable
private fun OnboardingScreen(
    allowBackDismiss: Boolean,
    onComplete: () -> Unit,
    onDismiss: () -> Unit,
) {
    var selectedPage by remember { mutableIntStateOf(0) }
    val page = onboardingPages[selectedPage]
    val isLastPage = selectedPage == onboardingPages.lastIndex

    // First-run onboarding must be explicitly completed; replayed onboarding can be dismissed.
    BackHandler(enabled = true) {
        if (allowBackDismiss) onDismiss()
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = Color.Transparent,
        contentColor = Color.White,
    ) {
        GradientBackground {
            Column(Modifier.fillMaxSize()) {
                OliloTopBar(title = "Welcome")
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 24.dp, vertical = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(28.dp),
                ) {
                    Icon(
                        page.icon,
                        contentDescription = null,
                        tint = LocalOliloTheme.current.accentColor,
                        modifier = Modifier.size(72.dp),
                    )
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Text(
                            page.title,
                            style = MaterialTheme.typography.headlineLarge,
                            fontWeight = FontWeight.Bold,
                            textAlign = TextAlign.Center,
                        )
                        Text(
                            page.message,
                            color = Color(0xFFCEC1D8),
                            textAlign = TextAlign.Center,
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }
                    StatusCard {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            page.highlights.forEach { highlight ->
                                Row(verticalAlignment = Alignment.Top) {
                                    Icon(
                                        Icons.Filled.CheckCircle,
                                        contentDescription = null,
                                        tint = LocalOliloTheme.current.accentColor,
                                        modifier = Modifier
                                            .padding(top = 2.dp)
                                            .size(20.dp),
                                    )
                                    Spacer(Modifier.width(12.dp))
                                    Text(
                                        highlight,
                                        color = Color.White,
                                        style = MaterialTheme.typography.bodyMedium,
                                        modifier = Modifier.weight(1f),
                                    )
                                }
                            }
                        }
                    }
                    OnboardingPageIndicator(selectedPage = selectedPage, pageCount = onboardingPages.size)
                }
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp, vertical = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Button(
                        onClick = {
                            // The primary button pages forward until the final page marks onboarding complete.
                            if (isLastPage) {
                                onComplete()
                            } else {
                                selectedPage += 1
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (isLastPage) "Start Using Olilo Status" else "Continue")
                    }
                    if (!isLastPage) {
                        TextButton(onClick = onComplete) {
                            Text("Skip Tutorial", color = Color(0xFFCEC1D8))
                        }
                    }
                }
            }
        }
    }
}

/** Shows compact progress dots for onboarding pages. */
@Composable
private fun OnboardingPageIndicator(selectedPage: Int, pageCount: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        repeat(pageCount) { index ->
            Box(
                modifier = Modifier
                    .size(if (index == selectedPage) 10.dp else 8.dp)
                    .clip(CircleShape)
                    .background(if (index == selectedPage) LocalOliloTheme.current.accentColor else Color(0x66CEC1D8)),
            )
        }
    }
}

/** Applies the dark Olilo Material theme to app content. */
@Composable
private fun OliloStatusTheme(theme: OliloTheme, content: @Composable () -> Unit) {
    val colorScheme = darkColorScheme(
        primary = theme.accentColor,
        secondary = Color(0xFF64B5F6),
        background = theme.backgroundColors.top,
        surface = theme.backgroundColors.mid.copy(alpha = 0.85f),
        surfaceVariant = theme.backgroundColors.mid.copy(alpha = 0.9f),
        onPrimary = Color.White,
        onSurface = Color.White,
        onSurfaceVariant = Color(0xFFE2D8EA),
    )
    CompositionLocalProvider(LocalOliloTheme provides theme) {
        MaterialTheme(colorScheme = colorScheme, content = content)
    }
}

/** Draws the shared full-screen gradient behind app content. */
@Composable
private fun GradientBackground(content: @Composable () -> Unit) {
    val theme = LocalOliloTheme.current
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.linearGradient(
                    listOf(
                        theme.backgroundColors.top,
                        theme.backgroundColors.mid,
                        theme.backgroundColors.bottom,
                    ),
                ),
            ),
    ) {
        content()
    }
}

@Composable
private fun themedStatusColor(status: String): Color =
    statusColor(status)

@Composable
private fun themedCardColor(): Color =
    LocalOliloTheme.current.backgroundColors.mid.copy(alpha = 0.7f)

@Composable
private fun themedChipColor(): Color =
    LocalOliloTheme.current.backgroundColors.mid.copy(alpha = 0.35f)

@Composable
private fun themedDialogColor(): Color =
    LocalOliloTheme.current.backgroundColors.mid.copy(alpha = 0.95f)

@Composable
private fun themedNavigationBarColor(): Color =
    LocalOliloTheme.current.backgroundColors.top.copy(alpha = 0.95f)

/** Renders the app toolbar with optional back, refresh, and configure actions. */
@Composable
private fun OliloTopBar(
    title: String,
    onRefresh: (() -> Unit)? = null,
    onConfigure: (() -> Unit)? = null,
    leadingIcon: ImageVector = Icons.Filled.Tune,
    leadingContentDescription: String = "Edit status components",
    navController: NavHostController? = null,
) {
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) {
        WindowInsets.statusBars.getTop(this).toDp()
    }
    val toolbarContentHeight = 48.dp

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(statusBarTopPadding + toolbarContentHeight)
            .padding(top = statusBarTopPadding),
    ) {
        if (navController != null) {
            IconButton(
                onClick = { navController.popBackStack() },
                modifier = Modifier.align(Alignment.CenterStart),
            ) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = LocalOliloTheme.current.accentColor,
                )
            }
        } else if (onConfigure != null) {
            IconButton(
                onClick = onConfigure,
                modifier = Modifier.align(Alignment.CenterStart),
            ) {
                Icon(
                    leadingIcon,
                    contentDescription = leadingContentDescription,
                    tint = LocalOliloTheme.current.accentColor,
                )
            }
        }
        Box(Modifier.align(Alignment.Center)) {
            Image(
                painter = painterResource(R.drawable.olilo),
                contentDescription = "Olilo $title",
                contentScale = ContentScale.Fit,
                modifier = Modifier.height(24.dp),
            )
        }
        if (onRefresh != null) {
            Row(modifier = Modifier.align(Alignment.CenterEnd)) {
                IconButton(onClick = onRefresh) {
                    Icon(
                        Icons.Filled.Refresh,
                        contentDescription = "Refresh",
                        tint = LocalOliloTheme.current.accentColor,
                    )
                }
            }
        }
    }
}

/** Shows a chip that opens a URL inside the app WebView. */
@Composable
private fun OpenUrlButton(
    label: String,
    url: String,
    navController: NavHostController,
    icon: ImageVector = Icons.AutoMirrored.Filled.OpenInNew,
) {
    AssistChip(
        onClick = { navController.openWeb(label, url) },
        label = { Text(label, color = Color.White) },
        leadingIcon = { Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp)) },
        colors = AssistChipDefaults.assistChipColors(
            labelColor = Color.White,
            leadingIconContentColor = LocalOliloTheme.current.accentColor,
            containerColor = themedChipColor(),
        ),
    )
}

/** Provides the shared translucent card container used by app sections. */
@Composable
private fun StatusCard(content: @Composable () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(20.dp),
        colors = CardDefaults.cardColors(
            containerColor = themedCardColor(),
            contentColor = Color.White,
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp),
    ) {
        Box(modifier = Modifier.padding(18.dp)) {
            content()
        }
    }
}

/** Displays a section title with a count and optional trailing action. */
@Composable
private fun SectionHeader(title: String, count: Int, action: (@Composable () -> Unit)? = null) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 2.dp)
            .semantics(mergeDescendants = true) {
                heading()
                contentDescription = "$title, $count"
            },
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.width(8.dp))
        Text("$count", style = MaterialTheme.typography.labelMedium, color = Color(0xFFCEC1D8))
        Spacer(Modifier.weight(1f))
        action?.invoke()
    }
}

/** Shows the common full-screen loading or retryable error state. */
@Composable
private fun LoadingOrError(
    loadingText: String,
    errorTitle: String,
    isLoading: Boolean,
    errorMessage: String?,
    onRetry: () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        when {
            isLoading -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                CircularProgressIndicator(color = LocalOliloTheme.current.accentColor)
                Spacer(Modifier.height(12.dp))
                Text(loadingText)
            }
            errorMessage != null -> Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.padding(24.dp),
            ) {
                Icon(Icons.Filled.Warning, contentDescription = null, tint = Color(0xFFFFB74D))
                Text(errorTitle, style = MaterialTheme.typography.titleMedium)
                Text(errorMessage, color = Color(0xFFCEC1D8))
                Button(onClick = onRetry) { Text("Retry") }
            }
        }
    }
}

private const val COMPONENT_PREFERENCES_NAME = "status_component_display_preferences"
private const val HIDDEN_COMPONENT_IDS_KEY = "hidden_component_ids"
private const val ORDERED_COMPONENT_IDS_KEY = "ordered_component_ids"

private data class ComponentDisplayPreferences(
    val hiddenComponentIds: Set<String> = emptySet(),
    val orderedComponentIds: List<String> = emptyList(),
) {
    /** Applies saved ordering while keeping new components at the end. */
    fun orderedComponents(components: List<StatusComponent>): List<StatusComponent> {
        val byId = components.associateBy { it.id }
        val ordered = orderedComponentIds.mapNotNull { byId[it] }
        val orderedIds = ordered.map { it.id }.toSet()
        return ordered + components.filterNot { it.id in orderedIds }
    }

    /** Filters groups down to visible components and drops empty groups. */
    fun visibleGroups(groups: List<StatusComponentGroup>): List<StatusComponentGroup> =
        groups.mapNotNull { group ->
            val visibleComponents = orderedComponents(group.allComponents).filterNot { it.id in hiddenComponentIds }
            if (visibleComponents.isEmpty()) {
                null
            } else {
                group.copy(parent = null, children = visibleComponents)
            }
        }

    /** Returns whether the component is currently shown in the status UI. */
    fun isVisible(component: StatusComponent): Boolean = component.id !in hiddenComponentIds

    /** Returns a copy with one component's visibility updated. */
    fun withVisibility(component: StatusComponent, isVisible: Boolean): ComponentDisplayPreferences =
        copy(hiddenComponentIds = if (isVisible) hiddenComponentIds - component.id else hiddenComponentIds + component.id)

    /** Returns a copy with one component moved within its group ordering. */
    fun moved(fromIndex: Int, toIndex: Int, group: StatusComponentGroup): ComponentDisplayPreferences {
        val groupComponentIds = group.allComponents.map { it.id }.toSet()
        val ids = orderedComponents(group.allComponents).map { it.id }.toMutableList()
        if (fromIndex !in ids.indices || toIndex !in ids.indices) return this
        val moved = ids.removeAt(fromIndex)
        ids.add(toIndex, moved)
        return copy(orderedComponentIds = orderedComponentIds.filterNot { it in groupComponentIds } + ids)
    }

    /** Returns a copy with all hidden components shown again. */
    fun withAllShown(): ComponentDisplayPreferences = copy(hiddenComponentIds = emptySet())
}

/** Loads saved status component display preferences from shared preferences. */
private fun loadComponentDisplayPreferences(context: Context): ComponentDisplayPreferences {
    val sharedPreferences = context.getSharedPreferences(COMPONENT_PREFERENCES_NAME, Context.MODE_PRIVATE)
    return ComponentDisplayPreferences(
        hiddenComponentIds = sharedPreferences.getStringSet(HIDDEN_COMPONENT_IDS_KEY, null).orEmpty().toSet(),
        orderedComponentIds = sharedPreferences.getString(ORDERED_COMPONENT_IDS_KEY, null)
            ?.split('|')
            ?.filter { it.isNotBlank() }
            .orEmpty(),
    )
}

/** Persists status component visibility and ordering preferences. */
private fun saveComponentDisplayPreferences(context: Context, preferences: ComponentDisplayPreferences) {
    context.getSharedPreferences(COMPONENT_PREFERENCES_NAME, Context.MODE_PRIVATE)
        .edit {
            putStringSet(HIDDEN_COMPONENT_IDS_KEY, preferences.hiddenComponentIds.toMutableSet())
                .putString(
                    ORDERED_COMPONENT_IDS_KEY,
                    preferences.orderedComponentIds.joinToString("|")
                )
        }
}

/** Returns affected components after applying display preferences. */
private fun visibleAffectedComponents(
    components: List<StatusComponent>,
    preferences: ComponentDisplayPreferences,
): List<StatusComponent> = preferences.orderedComponents(components)
    .filter { statusSeverity(it.status) > 0 }
    .filter { component ->
        component.id !in preferences.hiddenComponentIds
    }

/** Returns the highest-severity status among components still shown by the user. */
private fun visibleStatus(
    components: List<StatusComponent>,
    preferences: ComponentDisplayPreferences,
): String = components
    .filterNot { it.id in preferences.hiddenComponentIds }
    .maxByOrNull { statusSeverity(it.status) }
    ?.status ?: "OPERATIONAL"

/** Returns active incidents after applying display preferences to clearly referenced components. */
private fun visibleIncidents(
    incidents: List<Incident>,
    components: List<StatusComponent>,
    preferences: ComponentDisplayPreferences,
): List<Incident> {
    val visibleComponents = components.filterNot { it.id in preferences.hiddenComponentIds }
    val hiddenComponents = components.filter { it.id in preferences.hiddenComponentIds }
    return incidents.filter { incident ->
        val matchesVisibleComponent = visibleComponents.any { incident.references(it) }
        val matchesHiddenComponent = hiddenComponents.any { incident.references(it) }
        matchesVisibleComponent || !matchesHiddenComponent
    }
}

/** Returns whether the incident text clearly references a component name. */
private fun Incident.references(component: StatusComponent): Boolean =
    listOfNotNull(name, description).any { text ->
        text.referencesComponentName(component.name)
    }

/** Matches multi-word component names as phrases and short names as whole tokens. */
private fun String.referencesComponentName(componentName: String): Boolean {
    val normalizedName = componentName.lowercase()
    val normalizedText = lowercase()
    if (normalizedName.isBlank()) return false
    if (' ' in normalizedName) return normalizedName in normalizedText
    return normalizedText
        .split(Regex("[^a-z0-9]+"))
        .any { it == normalizedName }
}

/** Renders the main status dashboard screen. */
@Composable
private fun StatusScreen(navController: NavHostController, viewModel: StatusViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    var displayPreferences by remember { mutableStateOf(loadComponentDisplayPreferences(context)) }
    var showComponentEditor by remember { mutableStateOf(false) }

    /** Updates component display preferences and persists them immediately. */
    fun updateDisplayPreferences(preferences: ComponentDisplayPreferences) {
        displayPreferences = preferences
        saveComponentDisplayPreferences(context, preferences)
    }

    Column(Modifier.fillMaxSize()) {
        OliloTopBar(
            title = "Status",
            onRefresh = viewModel::refresh,
            onConfigure = { showComponentEditor = true },
        )
        if ((state.isLoading && state.summary == null) || state.errorMessage != null) {
            LoadingOrError(
                loadingText = "Loading status...",
                errorTitle = "Failed to load status",
                isLoading = state.isLoading && state.summary == null,
                errorMessage = state.errorMessage,
                onRetry = viewModel::refresh,
            )
            return@Column
        }

        val componentGroups = groupedComponents(state.components)
        val visibleComponentGroups = displayPreferences.visibleGroups(componentGroups)
        val visibleAffected = visibleAffectedComponents(state.components, displayPreferences)
        val visibleIncidents = visibleIncidents(state.incidents, state.components, displayPreferences)
        val visibleComponentCount = visibleComponentGroups.sumOf { it.allComponents.size }
        val visibleStatus = visibleStatus(state.components, displayPreferences)

        if (showComponentEditor) {
            ComponentDisplayEditorDialog(
                groups = componentGroups,
                preferences = displayPreferences,
                onPreferencesChange = ::updateDisplayPreferences,
                onDismiss = { showComponentEditor = false },
            )
        }

        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            state.summary?.let { summary ->
                item {
                    OverviewCard(
                        summary = summary,
                        state = state,
                        displayStatus = visibleStatus,
                        componentCount = visibleComponentCount,
                        affectedCount = visibleAffected.size,
                        incidentCount = visibleIncidents.size,
                        navController = navController,
                    )
                }
                item { StatusLinksCard(navController) }
                if (visibleAffected.isNotEmpty()) {
                    item { SectionHeader("Affected Services", visibleAffected.size) }
                    item {
                        StatusCard {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                visibleAffected.forEach { ComponentRow(it, showGroup = true) }
                            }
                        }
                    }
                }
            }

            if (visibleIncidents.isNotEmpty()) {
                item { SectionHeader("Active Incidents", visibleIncidents.size) }
                items(visibleIncidents, key = { it.id }) { incident -> IncidentCard(incident, navController) }
            }

            if (state.maintenances.isNotEmpty()) {
                item { SectionHeader("Maintenance", state.maintenances.size) }
                items(state.maintenances, key = { it.id }) { maintenance -> MaintenanceCard(maintenance, navController) }
            }

            if (visibleComponentGroups.isEmpty()) {
                item { SectionHeader("Components", visibleComponentCount) }
                item { EmptyComponentsCard() }
            } else {
                visibleComponentGroups.forEach { group ->
                    item(key = "${group.id}-header") {
                        SectionHeader(group.name, group.allComponents.size)
                    }
                    item(key = group.id) {
                        ComponentCategoryCard(group.allComponents)
                    }
                }
            }
        }
    }
}

/** Displays quick links to Olilo operational tools. */
@Composable
private fun StatusLinksCard(navController: NavHostController) {
    StatusCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatusLinkButton(
                    title = "Dashboard",
                    icon = Icons.Filled.Dashboard,
                    modifier = Modifier.weight(1f),
                    onClick = {
                        navController.openIframe(
                            "Dashboard",
                            "https://dashboard.as212683.net/d/olilo-public-status/overview?orgId=2&from=now-24h&to=now&timezone=browser&refresh=1m&kiosk=1",
                        )
                    },
                )
                StatusLinkButton(
                    title = "Portal",
                    icon = Icons.Filled.Work,
                    modifier = Modifier.weight(1f),
                    onClick = { navController.openWeb("Portal", "https://billing.olilo.co.uk") },
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                StatusLinkButton(
                    title = "Terminal",
                    icon = Icons.Filled.Terminal,
                    modifier = Modifier.weight(1f),
                    onClick = { navController.openWeb("Terminal", "https://terminal.olilo.co.uk") },
                )
                StatusLinkButton(
                    title = "Wiki",
                    icon = Icons.AutoMirrored.Filled.MenuBook,
                    modifier = Modifier.weight(1f),
                    onClick = { navController.openWeb("Wiki", "https://olilo.co.uk/wiki") },
                )
            }
        }
    }
}

/** Renders one status quick-link button. */
@Composable
private fun StatusLinkButton(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Button(onClick = onClick, modifier = modifier.height(48.dp)) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

/** Shows the component visibility and ordering editor dialog. */
@Composable
private fun ComponentDisplayEditorDialog(
    groups: List<StatusComponentGroup>,
    preferences: ComponentDisplayPreferences,
    onPreferencesChange: (ComponentDisplayPreferences) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Components") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.verticalScroll(rememberScrollState()),
            ) {
                Text(
                    "Hidden components are removed from the status page and affected-services summary.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFFCEC1D8),
                )
                groups.forEach { group ->
                    Text(
                        group.name,
                        style = MaterialTheme.typography.labelLarge,
                        color = Color(0xFFCEC1D8),
                    )
                    val orderedComponents = preferences.orderedComponents(group.allComponents)
                    orderedComponents.forEachIndexed { index, component ->
                        ComponentDisplayEditorRow(
                            component = component,
                            isVisible = preferences.isVisible(component),
                            canMoveUp = index > 0,
                            canMoveDown = index < orderedComponents.lastIndex,
                            onVisibilityChange = { isVisible ->
                                onPreferencesChange(preferences.withVisibility(component, isVisible))
                            },
                            onMoveUp = { onPreferencesChange(preferences.moved(index, index - 1, group)) },
                            onMoveDown = { onPreferencesChange(preferences.moved(index, index + 1, group)) },
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("Done") }
        },
        dismissButton = {
            TextButton(
                onClick = { onPreferencesChange(preferences.withAllShown()) },
                enabled = preferences.hiddenComponentIds.isNotEmpty(),
            ) {
                Text("Show All")
            }
        },
        containerColor = themedDialogColor(),
        titleContentColor = Color.White,
        textContentColor = Color.White,
    )
}

/** Renders one editable component row in the component editor. */
@Composable
private fun ComponentDisplayEditorRow(
    component: StatusComponent,
    isVisible: Boolean,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onVisibilityChange: (Boolean) -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) {
                contentDescription = "${component.name}, ${componentEditorDetail(component)}"
                stateDescription = if (isVisible) "Shown" else "Hidden"
            },
    ) {
        Column(Modifier.weight(1f)) {
            Text(component.name, color = Color.White, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(
                componentEditorDetail(component),
                style = MaterialTheme.typography.labelMedium,
                color = Color(0xFFCEC1D8),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        IconButton(onClick = onMoveUp, enabled = canMoveUp) {
            Icon(Icons.Filled.KeyboardArrowUp, contentDescription = "Move ${component.name} up", tint = LocalOliloTheme.current.accentColor)
        }
        IconButton(onClick = onMoveDown, enabled = canMoveDown) {
            Icon(Icons.Filled.KeyboardArrowDown, contentDescription = "Move ${component.name} down", tint = LocalOliloTheme.current.accentColor)
        }
        Switch(
            checked = isVisible,
            onCheckedChange = onVisibilityChange,
            modifier = Modifier.semantics {
                contentDescription = "${component.name} visibility"
                stateDescription = if (isVisible) "Shown" else "Hidden"
            },
        )
    }
}

/** Builds the secondary detail line for a component in the editor. */
private fun componentEditorDetail(component: StatusComponent): String = buildList {
    add(readableStatus(component.status))
    component.group?.name?.takeIf { it.isNotBlank() }?.let(::add)
    component.description?.takeIf { it.isNotBlank() }?.let(::add)
}.joinToString(" - ")

/** Shows the empty state when all components are hidden. */
@Composable
private fun EmptyComponentsCard() {
    StatusCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(Icons.Filled.VisibilityOff, contentDescription = null, tint = LocalOliloTheme.current.accentColor)
            Text("No components shown", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text("Use the component editor to show services on this page.", color = Color(0xFFCEC1D8))
        }
    }
}

/** Displays a status component category card. */
@Composable
private fun ComponentCategoryCard(components: List<StatusComponent>) {
    StatusCard {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            components.forEach { component ->
                ComponentRow(component, showGroup = false)
            }
        }
    }
}

/** Displays the overall status summary and headline metrics. */
@Composable
private fun OverviewCard(
    summary: StatusPageSummary,
    state: StatusScreenState,
    displayStatus: String,
    componentCount: Int,
    affectedCount: Int,
    incidentCount: Int,
    navController: NavHostController,
) {
    StatusCard {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(verticalAlignment = Alignment.Top) {
                PulsingStatusIcon(displayStatus)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text("Olilo Network Status", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                    Text(
                        if (statusSeverity(displayStatus) == 0) "All systems operational" else readableStatus(
                            displayStatus
                        ),
                        color = Color(0xFFCEC1D8),
                    )
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MetricTile("Components", componentCount.toString(), Modifier.weight(1f))
                MetricTile("Affected", affectedCount.toString(), Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MetricTile("Incidents", incidentCount.toString(), Modifier.weight(1f))
                MetricTile("Maintenance", state.maintenances.size.toString(), Modifier.weight(1f))
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                OpenUrlButton("Olilo Status", summary.page.url, navController, Icons.Filled.Dashboard)
                Spacer(Modifier.weight(1f))
                formatTime(state.lastRefreshedMillis)?.let {
                    Text("Updated $it", style = MaterialTheme.typography.labelMedium, color = Color(0xFFCEC1D8))
                }
            }
        }
    }
}

/** STATUS ICON ANIMATION
Animated status severity icon, doesn't match the iOS implementaion exactly due to android's
difference of accessibilty settings. Will be enabled regardless of settings. */

/** Displays the animated status icon used by the overview card. */
@Composable
private fun PulsingStatusIcon(status: String) {
    val color = themedStatusColor(status)
    val readable = readableStatus(status)
    val icon = if (statusSeverity(status) == 0) Icons.Filled.CheckCircle else Icons.Filled.Error
    val transition = rememberInfiniteTransition(label = "Status icon pulse")
    val pulse by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1400),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "Status icon pulse progress",
    )

    Box(
        modifier = Modifier.size(44.dp),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = color.copy(alpha = 0.18f),
            modifier = Modifier
                .size(38.dp)
                .graphicsLayer {
                    scaleX = 1f + (pulse * 0.45f)
                    scaleY = 1f + (pulse * 0.45f)
                    alpha = pulse
                },
        )
        Icon(
            icon,
            contentDescription = "Status: $readable",
            tint = color,
            modifier = Modifier.size(38.dp),
        )
    }
}

/** Displays one compact metric tile. */
@Composable
private fun MetricTile(title: String, value: String, modifier: Modifier = Modifier) {
    Surface(
        modifier = modifier
            .height(72.dp)
            .semantics(mergeDescendants = true) {
                contentDescription = "$title: $value"
            },
        shape = RoundedCornerShape(14.dp),
        color = themedChipColor(),
        contentColor = Color.White,
    ) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.SpaceBetween) {
            Text(title, style = MaterialTheme.typography.labelMedium, color = Color(0xFFCEC1D8))
            Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        }
    }
}

/** Renders an active incident card with details and optional link. */
@Composable
private fun IncidentCard(incident: Incident, navController: NavHostController) {
    StatusCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            TitleStatusRow(incident.name, readableStatus(incident.status), incident.impact ?: incident.status)
            DetailRows(
                listOf(
                    "Started" to formatRemoteDate(incident.started),
                    "Updated" to formatRemoteDate(incident.updatedAt),
                    "ID" to incident.id,
                ),
            )
            incident.description?.takeIf { it.isNotBlank() }?.let { ExpandableDescription(it) }
            incident.url?.let { OpenUrlButton("Open incident", it, navController) }
        }
    }
}

/** Renders an active maintenance card with schedule details and optional link. */
@Composable
private fun MaintenanceCard(maintenance: Maintenance, navController: NavHostController) {
    StatusCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            TitleStatusRow(maintenance.name, readableStatus(maintenance.status), maintenance.status)
            DetailRows(
                listOf(
                    "Start" to formatRemoteDate(maintenance.start),
                    "Duration" to maintenance.duration?.let { "$it minutes" },
                    "Updated" to formatRemoteDate(maintenance.updatedAt),
                    "ID" to maintenance.id,
                ),
            )
            maintenance.url?.let { OpenUrlButton("Open maintenance", it, navController) }
        }
    }
}

/** Displays one status component row with status and optional group details. */
@Composable
private fun ComponentRow(component: StatusComponent, showGroup: Boolean) {
    val detail = buildList {
        add(readableStatus(component.status))
        if (showGroup) component.group?.name?.let(::add)
        component.description?.takeIf { it.isNotBlank() }?.let(::add)
    }.joinToString(" - ")
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) {
                contentDescription = "${component.name}, $detail"
            },
    ) {
        StatusDot(component.status, 8)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(component.name, color = Color.White, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(detail, style = MaterialTheme.typography.labelMedium, color = Color(0xFFCEC1D8), maxLines = 2)
        }
        StatusBadge(readableStatus(component.status), component.status)
    }
}

/** Renders the notices tab, including current notices and filtered history. */
@Composable
private fun NoticesScreen(navController: NavHostController, viewModel: NoticesViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val filtered = state.notices
        .filter { notice -> state.selectedKind == null || notice.kind == state.selectedKind }
        .filter { notice -> !state.hideOldNotices || !notice.isOlderThan30Days() }

    Column(Modifier.fillMaxSize()) {
        OliloTopBar(
            title = "Notices",
            onRefresh = viewModel::refresh,
            onConfigure = viewModel::toggleOldNotices,
            leadingIcon = if (state.hideOldNotices) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
            leadingContentDescription = if (state.hideOldNotices) {
                "Show notices older than 30 days"
            } else {
                "Hide notices older than 30 days"
            },
        )
        if ((state.isLoading && state.notices.isEmpty()) || state.errorMessage != null) {
            LoadingOrError(
                loadingText = "Loading notices...",
                errorTitle = "Failed to load notices",
                isLoading = state.isLoading && state.notices.isEmpty(),
                errorMessage = state.errorMessage,
                onRetry = viewModel::refresh,
            )
            return@Column
        }

        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            val activeCount = state.activeIncidents.size + state.activeMaintenances.size
            if (activeCount > 0) {
                item { SectionHeader("Current Notices", activeCount) }
                items(state.activeIncidents, key = { "current-incident-${it.id}" }) { ActiveIncidentNoticeCard(it, navController) }
                items(state.activeMaintenances, key = { "current-maintenance-${it.id}" }) { ActiveMaintenanceNoticeCard(it, navController) }
            }

            item {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    NoticeFilterChip(selected = state.selectedKind == null, label = "All") { viewModel.selectKind(null) }
                    NoticeFilterChip(selected = state.selectedKind == NoticeKind.Incident, label = "Incident") { viewModel.selectKind(
                        NoticeKind.Incident) }
                    NoticeFilterChip(selected = state.selectedKind == NoticeKind.Maintenance, label = "Maintenance") { viewModel.selectKind(
                        NoticeKind.Maintenance) }
                }
            }
            item { SectionHeader("Notice History", filtered.size) }
            items(filtered, key = { "history-notice-${it.id}" }) { NoticeHistoryCard(it, navController) }
        }
    }
}

/** Returns true when a historical notice is older than the default history window. */
private fun StatusNotice.isOlderThan30Days(now: Instant = Instant.now()): Boolean {
    val timestamp = updated ?: published ?: return false
    val noticeDate = runCatching { Instant.parse(timestamp) }.getOrNull() ?: return false
    return noticeDate.isBefore(now.minus(30, ChronoUnit.DAYS))
}

/** Renders an active incident notice card. */
@Composable
private fun ActiveIncidentNoticeCard(incident: Incident, navController: NavHostController) {
    StatusCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            NoticeTitleRow(incident.name, "Incident", Icons.Filled.Warning, incident.impact ?: incident.status)
            DetailRows(
                listOf(
                    "Status" to readableStatus(incident.status),
                    "Impact" to incident.impact?.let(::readableStatus),
                    "Started" to formatRemoteDate(incident.started),
                    "Updated" to formatRemoteDate(incident.updatedAt),
                ),
            )
            incident.description?.takeIf { it.isNotBlank() }?.let { ExpandableDescription(it) }
            incident.url?.let { OpenUrlButton("Open incident", it, navController) }
        }
    }
}

/** Displays a selectable notice filter chip. */
@Composable
private fun NoticeFilterChip(selected: Boolean, label: String, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(label) },
        colors = FilterChipDefaults.filterChipColors(
            labelColor = Color.White,
            selectedLabelColor = Color.White,
            containerColor = themedChipColor(),
            selectedContainerColor = LocalOliloTheme.current.accentColor.copy(alpha = 0.35f),
        ),
    )
}

/** Shows collapsible long-form text with a show more control. */
@Composable
private fun ExpandableDescription(text: String, collapsedLines: Int = 4) {
    var expanded by remember(text) { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text,
            maxLines = if (expanded) Int.MAX_VALUE else collapsedLines,
            overflow = TextOverflow.Ellipsis,
        )
        AssistChip(
            onClick = { expanded = !expanded },
            label = { Text(if (expanded) "Show less" else "Show more") },
            colors = AssistChipDefaults.assistChipColors(
                labelColor = Color.White,
                containerColor = themedChipColor(),
            ),
        )
    }
}

/** Renders an active maintenance notice card. */
@Composable
private fun ActiveMaintenanceNoticeCard(maintenance: Maintenance, navController: NavHostController) {
    StatusCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            NoticeTitleRow(maintenance.name, "Maintenance", Icons.Filled.Work, maintenance.status)
            DetailRows(
                listOf(
                    "Status" to readableStatus(maintenance.status),
                    "Start" to formatRemoteDate(maintenance.start),
                    "Duration" to maintenance.duration?.let { "$it minutes" },
                    "Updated" to formatRemoteDate(maintenance.updatedAt),
                ),
            )
            maintenance.url?.let { OpenUrlButton("Open maintenance", it, navController) }
        }
    }
}

/** Renders a historical notice card with optional updates and link. */
@Composable
private fun NoticeHistoryCard(notice: StatusNotice, navController: NavHostController) {
    var descriptionExpanded by remember(notice.id) { mutableStateOf(false) }
    var updatesExpanded by remember(notice.id) { mutableStateOf(false) }

    StatusCard {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            NoticeTitleRow(
                notice.title,
                notice.kind.label,
                if (notice.kind == NoticeKind.Maintenance) Icons.Filled.Work else Icons.Filled.Notifications,
                if (notice.kind == NoticeKind.Maintenance) "UNDERMAINTENANCE" else "PARTIALOUTAGE",
            )
            DetailRows(
                listOf(
                    "Published" to formatRemoteDate(notice.published),
                    "Updated" to formatRemoteDate(notice.updated),
                    "Duration" to notice.duration,
                    "Components" to notice.affectedComponents,
                ),
            )
            Text(
                notice.summary,
                maxLines = if (descriptionExpanded) Int.MAX_VALUE else 5,
                overflow = TextOverflow.Ellipsis,
            )
            notice.updates.takeIf { it.isNotEmpty() }?.let { updates ->
                if (updatesExpanded) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        updates.forEach { update ->
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(update.status, color = themedStatusColor(update.status), fontWeight = FontWeight.Bold, style = MaterialTheme.typography.labelMedium)
                                Text(update.message, style = MaterialTheme.typography.labelMedium, color = Color(0xFFCEC1D8))
                            }
                        }
                    }
                }
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.horizontalScroll(rememberScrollState()),
            ) {
                AssistChip(
                    onClick = { descriptionExpanded = !descriptionExpanded },
                    label = { Text(if (descriptionExpanded) "Show less" else "Show more") },
                    colors = AssistChipDefaults.assistChipColors(
                        labelColor = Color.White,
                        containerColor = themedChipColor(),
                    ),
                )
                notice.updates.takeIf { it.isNotEmpty() }?.let { updates ->
                    AssistChip(
                        onClick = { updatesExpanded = !updatesExpanded },
                        label = { Text("${updates.size} update${if (updates.size == 1) "" else "s"}") },
                        colors = AssistChipDefaults.assistChipColors(
                            labelColor = Color.White,
                            containerColor = LocalOliloTheme.current.accentColor.copy(alpha = 0.25f),
                        ),
                    )
                }
                notice.link?.let { OpenUrlButton("Open notice", it, navController) }
            }
        }
    }
}

/** Displays a notice title row with icon and status badge. */
@Composable
private fun NoticeTitleRow(title: String, subtitle: String, icon: ImageVector, status: String) {
    Row(
        verticalAlignment = Alignment.Top,
        modifier = Modifier.semantics(mergeDescendants = true) {
            contentDescription = "$title, $subtitle, ${readableStatus(status)}"
        },
    ) {
        Icon(icon, contentDescription = null, tint = LocalOliloTheme.current.accentColor, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(subtitle, style = MaterialTheme.typography.labelMedium, color = Color(0xFFCEC1D8))
        }
        StatusBadge(readableStatus(status), status)
    }
}

/** Displays a status title row with dot and badge. */
@Composable
private fun TitleStatusRow(title: String, subtitle: String, status: String) {
    Row(
        verticalAlignment = Alignment.Top,
        modifier = Modifier.semantics(mergeDescendants = true) {
            contentDescription = "$title, $subtitle, ${readableStatus(status)}"
        },
    ) {
        StatusDot(status, 10)
        Spacer(Modifier.width(10.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(subtitle, style = MaterialTheme.typography.labelMedium, color = Color(0xFFCEC1D8))
        }
        StatusBadge(readableStatus(status), status)
    }
}

/** Draws a small colored dot for a backend status. */
@Composable
private fun StatusDot(status: String, size: Int) {
    Box(
        Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(themedStatusColor(status)),
    )
}

/** Displays a compact status badge. */
@Composable
private fun StatusBadge(text: String, status: String) {
    Surface(
        shape = RoundedCornerShape(50),
        color = themedStatusColor(status).copy(alpha = 0.16f),
        contentColor = themedStatusColor(status),
    ) {
        Text(
            text,
            color = themedStatusColor(status),
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
            maxLines = 1,
        )
    }
}

/** Displays only detail rows whose values are present. */
@Composable
private fun DetailRows(rows: List<Pair<String, String?>>) {
    val visible = rows.filter { !it.second.isNullOrBlank() }
    if (visible.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        visible.forEach { (label, value) ->
            Row {
                Text(label, color = Color(0xFFCEC1D8), style = MaterialTheme.typography.labelMedium, modifier = Modifier.width(96.dp))
                Text(value.orEmpty(), style = MaterialTheme.typography.labelMedium, modifier = Modifier.weight(1f))
            }
        }
    }
}

/** Renders the settings tab. */
@Composable
private fun SettingsScreen(navController: NavHostController) {
    val context = LocalContext.current

    Column(Modifier.fillMaxSize()) {
        OliloTopBar(title = "Settings")
        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                SettingsSection("Notifications") {
                    SettingsNavRow("Status Updates", Icons.Filled.Notifications, showDivider = false) {
                        navController.navigate("notification-settings")
                    }
                }
            }
            item {
                SettingsSection("Appearance") {
                    SettingsNavRow("Theme", Icons.Filled.Tune, showDivider = false) {
                        navController.navigate("appearance-settings")
                    }
                }
            }
            item {
                SettingsSection("Support") {
                    SettingsNavRow("Contact Us", Icons.Filled.Email) { navController.navigate("contact") }
                    SettingsLinkRow(
                        "Report a Problem",
                        "https://gitlab.com/team-olilo/olilo-status/-/boards/11373269",
                        Icons.Filled.ReportProblem,
                        navController,
                        showDivider = false,
                    )
                }
            }
            item {
                SettingsSection("Contributors") {
                    SettingsNavRow("Credits", Icons.Filled.Info, showDivider = false) { navController.navigate("credits") }
                }
            }
            item {
                SettingsSection("Compliance") {
                    SettingsLinkRow("Privacy Policy", "https://olilo.co.uk/privacy", Icons.Filled.Description, navController)
                    SettingsLinkRow(
                        "Terms & Conditions",
                        "https://olilo.co.uk/terms",
                        Icons.Filled.Description,
                        navController,
                        showDivider = false,
                    )
                }
            }
            item {
                SettingsSection("Version") {
                    SettingsLinkRow(
                        title = "Contribute to Olilo Status",
                        url = "https://gitlab.com/team-olilo/status-app",
                        icon = Icons.Filled.Language,
                        navController = navController,
                        logoResId = R.drawable.logo_gitlab,
                        showDivider = false,
                    )
                    Text(
                        appVersion(context),
                        color = Color(0xFFCEC1D8),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier
                            .align(Alignment.CenterHorizontally)
                            .border(
                                width = 1.dp,
                                color = Color(0x59CEC1D8),
                                shape = RoundedCornerShape(8.dp),
                            )
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                        textAlign = TextAlign.Center,
                    )
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                        Spacer(Modifier.height(8.dp))
                        Image(
                            painter = painterResource(R.drawable.olilo),
                            contentDescription = "Olilo",
                            contentScale = ContentScale.Fit,
                            modifier = Modifier.height(44.dp),
                        )
                        Spacer(Modifier.height(12.dp))
                        Text(
                            "(c) 2026 Olilo UK & Ireland Ltd. Company number: 16352417",
                            color = Color(0xFFCEC1D8),
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                }
            }
        }
    }
}

/** Renders app-wide appearance controls. */
@Composable
private fun AppearanceSettingsScreen(
    navController: NavHostController,
    onThemeSelected: (OliloTheme) -> Boolean,
) {
    val context = LocalContext.current
    val selectedTheme = LocalOliloTheme.current
    var isRestartDialogVisible by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize()) {
        OliloTopBar(title = "Appearance", navController = navController)
        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                SettingsSection("Theme") {
                    OliloTheme.entries.forEachIndexed { index, theme ->
                        ListItem(
                            headlineContent = { Text(theme.displayName, color = Color.White) },
                            leadingContent = {
                                Box(
                                    modifier = Modifier
                                        .size(20.dp)
                                        .clip(CircleShape)
                                        .background(theme.accentColor),
                                )
                            },
                            trailingContent = {
                                if (theme == selectedTheme) {
                                    Icon(
                                        Icons.Filled.CheckCircle,
                                        contentDescription = "Selected",
                                        tint = LocalOliloTheme.current.accentColor,
                                    )
                                }
                            },
                            colors = ListItemDefaults.colors(
                                containerColor = Color.Transparent,
                                headlineColor = Color.White,
                            ),
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(Color.Transparent)
                                .clickable {
                                    if (theme != selectedTheme) {
                                        isRestartDialogVisible = onThemeSelected(theme)
                                    }
                                }
                                .semantics {
                                    role = Role.Button
                                    stateDescription = if (theme == selectedTheme) "Selected" else "Not selected"
                                },
                        )
                        if (index != OliloTheme.entries.lastIndex) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(1.dp)
                                    .background(Color.White.copy(alpha = 0.06f)),
                            )
                        }
                    }
                    Text(
                        "The selected colour is used across app controls, links, icons, and the app background.",
                        color = Color(0xFFCEC1D8),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                }
            }
        }
    }

    if (isRestartDialogVisible) {
        AlertDialog(
            onDismissRequest = {},
            title = { Text("Restart required") },
            text = { Text("Olilo Status will close now. Reopen it to finish applying your theme.") },
            confirmButton = {
                TextButton(onClick = { closeAppForRestart(context) }) {
                    Text("Close App")
                }
            },
            containerColor = themedDialogColor(),
            titleContentColor = Color.White,
            textContentColor = Color.White,
        )
    }
}

/** Renders notification opt-in and preference controls. */
@Composable
private fun NotificationSettingsScreen(navController: NavHostController) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var isEnabled by remember { mutableStateOf(NotificationStore.isEnabled(context)) }
    var preferences by remember { mutableStateOf(NotificationStore.preferences(context)) }
    var isSaving by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    val networks = listOf("Openreach", "CityFibre", "Freedom Fibre")

    /** Enables notifications and registers this device with the backend. */
    fun enableNotifications() {
        isSaving = true
        errorMessage = null
        scope.launch {
            runCatching { OliloNotifications.enable(context) }
                .onSuccess { isEnabled = true }
                .onFailure { error ->
                    isEnabled = false
                    errorMessage = error.localizedMessage ?: "Unable to enable notifications"
                }
            isSaving = false
        }
    }

    /** Disables notifications and unregisters this device from delivery. */
    fun disableNotifications() {
        isSaving = true
        errorMessage = null
        scope.launch {
            runCatching { OliloNotifications.disable(context) }
                .onSuccess { isEnabled = false }
                .onFailure { error ->
                    isEnabled = false
                    errorMessage = error.localizedMessage ?: "Unable to disable notifications"
                }
            isSaving = false
        }
    }

    /** Saves notification preferences locally and pushes them to the backend. */
    fun updatePreferences(next: NotificationPreferences) {
        preferences = next
        errorMessage = null
        scope.launch {
            runCatching { OliloNotifications.updatePreferences(context, next) }
                .onFailure { error ->
                    errorMessage = error.localizedMessage ?: "Unable to update notification preferences"
                }
        }
    }

    val hasEnabledNotificationType =
        preferences.incidents || preferences.maintenance || preferences.componentAlerts

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            enableNotifications()
        } else {
            isEnabled = false
            NotificationStore.setEnabled(context, false)
        }
    }

    /** Handles the notification master toggle and runtime permission request. */
    fun onEnabledChange(next: Boolean) {
        if (next) {
            val permission = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            if (permission == PackageManager.PERMISSION_GRANTED) {
                enableNotifications()
            } else {
                permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        } else {
            disableNotifications()
        }
    }

    Column(Modifier.fillMaxSize()) {
        OliloTopBar(title = "Status Updates", navController = navController)
        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                SettingsSection("Notifications") {
                    SettingsToggleRow(
                        title = "Enable notifications",
                        icon = Icons.Filled.Notifications,
                        checked = isEnabled,
                        enabled = !isSaving,
                        showDivider = false,
                        onCheckedChange = ::onEnabledChange,
                    )
                    Text(
                        "Get notified about Olilo Network updates on this device.",
                        color = Color(0xFFCEC1D8),
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                }
            }

            if (isEnabled) {
                item {
                    SettingsSection("Notify me about") {
                        SettingsToggleRow(
                            title = "Incidents",
                            icon = Icons.Filled.Warning,
                            checked = preferences.incidents,
                            onCheckedChange = { updatePreferences(preferences.copy(incidents = it)) },
                        )
                        SettingsToggleRow(
                            title = "Scheduled maintenance",
                            icon = Icons.Filled.Work,
                            checked = preferences.maintenance,
                            onCheckedChange = { updatePreferences(preferences.copy(maintenance = it)) },
                        )
                        SettingsToggleRow(
                            title = "Component status changes",
                            icon = Icons.Filled.Dashboard,
                            checked = preferences.componentAlerts,
                            showDivider = false,
                            onCheckedChange = { updatePreferences(preferences.copy(componentAlerts = it)) },
                        )
                        Text(
                            "Choose which notices you get notified about.",
                            color = Color(0xFFCEC1D8),
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                        )
                    }
                }

                if (hasEnabledNotificationType) {
                    item {
                        SettingsSection("Networks") {
                            networks.forEachIndexed { index, network ->
                                SettingsToggleRow(
                                    title = network,
                                    icon = Icons.Filled.Language,
                                    checked = network in preferences.networks,
                                    showDivider = index != networks.lastIndex,
                                    onCheckedChange = { checked ->
                                        val nextNetworks = if (checked) {
                                            (preferences.networks + network).distinct()
                                        } else {
                                            preferences.networks.filterNot { it == network }
                                        }
                                        updatePreferences(preferences.copy(networks = nextNetworks))
                                    },
                                )
                            }
                            Text(
                                "With none selected, alerts are sent for all networks.",
                                color = Color(0xFFCEC1D8),
                                style = MaterialTheme.typography.bodySmall,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                            )
                        }
                    }
                }
            }

            errorMessage?.let { message ->
                item {
                    StatusCard {
                        Text(message, color = Color(0xFFFFB74D), style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }
        }
    }
}

/** Returns the installed app version displayed in settings. */
private fun appVersion(context: Context): String {
    val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
    return packageInfo.versionName.orEmpty().ifBlank { "Unknown" }
}

/** Groups related settings rows inside a shared card. */
@Composable
private fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(title, style = MaterialTheme.typography.titleSmall, color = Color(0xFFCEC1D8), modifier = Modifier.padding(horizontal = 4.dp))
        StatusCard {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp), content = content)
        }
    }
}

/** Renders a settings row that opens a URL in the in-app WebView. */
@Composable
private fun SettingsLinkRow(
    title: String,
    url: String,
    icon: ImageVector,
    navController: NavHostController,
    logoResId: Int? = null,
    showDivider: Boolean = true,
) {
    SettingsRow(
        title = title,
        icon = icon,
        onClick = { navController.openWeb(title, url) },
        logoResId = logoResId,
        showDivider = showDivider,
    )
}

/** Renders a settings row that opens an external Android intent. */
@Composable
private fun SettingsExternalRow(
    title: String,
    url: String,
    icon: ImageVector,
    showDivider: Boolean = true,
    logoResId: Int? = null,
) {
    val context = LocalContext.current
    SettingsRow(
        title = title,
        icon = icon,
        onClick = {
            context.startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
        },
        logoResId = logoResId,
        showDivider = showDivider,
    )
}

/** Renders a settings row that navigates within the app. */
@Composable
private fun SettingsNavRow(title: String, icon: ImageVector, showDivider: Boolean = true, onClick: () -> Unit) {
    SettingsRow(title, icon, onClick, showDivider = showDivider)
}

/** Renders a settings row controlled by a switch. */
@Composable
private fun SettingsToggleRow(
    title: String,
    icon: ImageVector,
    checked: Boolean,
    enabled: Boolean = true,
    showDivider: Boolean = true,
    onCheckedChange: (Boolean) -> Unit,
) {
    ListItem(
        headlineContent = { Text(title, color = Color.White) },
        leadingContent = { Icon(icon, contentDescription = null, tint = LocalOliloTheme.current.accentColor) },
        trailingContent = {
            Switch(
                checked = checked,
                enabled = enabled,
                onCheckedChange = null,
            )
        },
        colors = ListItemDefaults.colors(
            containerColor = Color.Transparent,
            headlineColor = Color.White,
            leadingIconColor = LocalOliloTheme.current.accentColor,
        ),
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.Transparent)
            .toggleable(
                value = checked,
                enabled = enabled,
                role = Role.Switch,
                onValueChange = onCheckedChange,
            )
            .semantics {
                stateDescription = if (checked) "On" else "Off"
            },
    )
    if (showDivider) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(Color.White.copy(alpha = 0.06f)),
        )
    }
}

/** Renders the base visual layout for clickable settings rows. */
@Composable
private fun SettingsRow(
    title: String,
    icon: ImageVector,
    onClick: () -> Unit,
    logoResId: Int? = null,
    showDivider: Boolean = true,
) {
    ListItem(
        headlineContent = { Text(title, color = Color.White) },
        leadingContent = {
            if (logoResId != null) {
                Image(
                    painter = painterResource(logoResId),
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                )
            } else {
                Icon(icon, contentDescription = null, tint = LocalOliloTheme.current.accentColor)
            }
        },
        colors = ListItemDefaults.colors(
            containerColor = Color.Transparent,
            headlineColor = Color.White,
            leadingIconColor = LocalOliloTheme.current.accentColor,
        ),
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.Transparent)
            .clickable(onClick = onClick)
            .semantics {
                role = Role.Button
            },
    )
    if (showDivider) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(Color.White.copy(alpha = 0.06f)),
        )
    }
}

/** Displays an in-app WebView page with a top bar. */
@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun WebPage(navController: NavHostController, title: String, url: String) {
    Column(Modifier.fillMaxSize()) {
        OliloTopBar(title = title, navController = navController)
        AndroidView(
            factory = { context ->
                WebView(context).apply {
                    webViewClient = WebViewClient()
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true
                    loadUrl(url)
                }
            },
            update = {},
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .semantics {
                    contentDescription = "$title web content"
                },
        )
    }
}

/** Displays an in-app iframe page with a top bar. */
@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun IframePage(navController: NavHostController, title: String, url: String) {
    Column(Modifier.fillMaxSize()) {
        OliloTopBar(title = title, navController = navController)
        AndroidView(
            factory = { context ->
                WebView(context).apply {
                    webViewClient = dashboardWebViewClient()
                    settings.javaScriptEnabled = true
                    settings.javaScriptCanOpenWindowsAutomatically = true
                    settings.domStorageEnabled = true
                    settings.databaseEnabled = true
                    settings.cacheMode = WebSettings.LOAD_NO_CACHE
                    settings.mediaPlaybackRequiresUserGesture = false
                    settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                    settings.loadWithOverviewMode = true
                    settings.useWideViewPort = true
                    settings.builtInZoomControls = true
                    settings.displayZoomControls = false
                    settings.userAgentString = desktopChromeUserAgent
                    isHorizontalScrollBarEnabled = true
                    isVerticalScrollBarEnabled = true
                    overScrollMode = WebView.OVER_SCROLL_ALWAYS
                    CookieManager.getInstance().setAcceptCookie(true)
                    CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
                    loadUrl(url)
                }
            },
            update = {},
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .semantics {
                    contentDescription = "$title dashboard content"
                },
        )
    }
}

private const val desktopChromeUserAgent =
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

private fun dashboardWebViewClient(): WebViewClient = object : WebViewClient() {
    override fun onPageFinished(view: WebView?, url: String?) {
        view?.evaluateJavascript(dashboardViewportFixScript(view.height), null)
    }
}

private fun dashboardViewportFixScript(viewportHeight: Int): String {
    val height = viewportHeight.coerceAtLeast(800)
    return """
        (() => {
            const height = '${height}px';
            const styleId = 'olilo-dashboard-viewport-fix';
            let style = document.getElementById(styleId);
            if (!style) {
                style = document.createElement('style');
                style.id = styleId;
                document.head.appendChild(style);
            }
            style.textContent = `
                html,
                body,
                #reactRoot,
                .main-view,
                .grafana-app,
                [data-testid="dashboard-container"] {
                    width: max-content !important;
                    min-width: 1200px !important;
                    min-height: ${'$'}{height} !important;
                    height: ${'$'}{height} !important;
                    overflow: auto !important;
                }
            `;
            [document.documentElement, document.body, document.getElementById('reactRoot')]
                .filter(Boolean)
                .forEach((element) => {
                    element.style.setProperty('width', 'max-content', 'important');
                    element.style.setProperty('min-width', '1200px', 'important');
                    element.style.setProperty('overflow', 'auto', 'important');
                    element.style.setProperty('min-height', height, 'important');
                    element.style.setProperty('height', height, 'important');
                });
        })()
    """.trimIndent()
}

/** Renders the contact page with social and email links. */
@Composable
private fun ContactUsPage(navController: NavHostController) {
    Column(Modifier.fillMaxSize()) {
        OliloTopBar(title = "Contact Us", navController = navController)
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text("Social", style = MaterialTheme.typography.titleMedium, color = Color(0xFFCEC1D8))
            StatusCard {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    SettingsLinkRow(
                        "Find us on Discord",
                        "https://discord.gg/olilo",
                        Icons.Filled.Language,
                        navController,
                        R.drawable.logo_discord,
                    )
                    SettingsLinkRow(
                        "Find us on Reddit",
                        "https://www.reddit.com/r/Olilo",
                        Icons.Filled.Language,
                        navController,
                        R.drawable.logo_reddit,
                        showDivider = false,
                    )
                }
            }
            Text(
                "Support links will open to external sites.",
                color = Color(0xFFCEC1D8),
                style = MaterialTheme.typography.bodySmall,
            )
            Text("Email", style = MaterialTheme.typography.titleMedium, color = Color(0xFFCEC1D8))
            StatusCard {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    SettingsExternalRow(
                        "Olilo Support",
                        "mailto:support@olilo.co.uk",
                        Icons.Filled.Email,
                    )
                    SettingsExternalRow(
                        "Olilo Sales",
                        "mailto:sales@olilo.co.uk",
                        Icons.Filled.Email,
                        showDivider = false,
                    )
                }
            }
            Text(
                "Please provide as much useful information as possible.",
                color = Color(0xFFCEC1D8),
                style = MaterialTheme.typography.bodySmall,
            )
            Spacer(Modifier.height(44.dp))
            Image(
                painter = painterResource(R.drawable.olilo),
                contentDescription = "Olilo",
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .height(36.dp)
                    .align(Alignment.CenterHorizontally),
            )
        }
    }
}

/** Renders the contributor credits page. */
@Composable
private fun CreditsPage(navController: NavHostController) {
    Column(Modifier.fillMaxSize()) {
        OliloTopBar(title = "Credits", navController = navController)
        Column(
            modifier = Modifier
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
                .fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text("Meet the Developers", style = MaterialTheme.typography.titleMedium, color = Color(0xFFCEC1D8))
            StatusCard {
                Text("Olilo Status is a community built application overseen by the official Olilo Team. Listed below are the developers that helped put Olilo Status together.")
            }
            Text("Olilo Status Contributors", style = MaterialTheme.typography.titleMedium, color = Color(0xFFCEC1D8))
            StatusCard {
                Text("Aaron Doe (Developer)")
            }
            StatusCard {
                Text("Aydan Abrahams (Developer)")
            }
            Spacer(Modifier.height(44.dp))
            Image(
                painter = painterResource(R.drawable.olilo),
                contentDescription = "Olilo",
                contentScale = ContentScale.Fit,
                modifier = Modifier
                    .height(36.dp)
                    .align(Alignment.CenterHorizontally),
            )
        }
    }
}
