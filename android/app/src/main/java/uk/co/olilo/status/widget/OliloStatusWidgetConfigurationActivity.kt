package uk.co.olilo.status.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import uk.co.olilo.status.status.OliloTheme
import uk.co.olilo.status.status.loadOliloTheme

class OliloStatusWidgetConfigurationActivity : ComponentActivity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    /** Initializes widget configuration and saves the selected source before finishing. */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContent {
            WidgetConfigurationScreen(
                theme = loadOliloTheme(this),
                onSourceSelected = { sourceName ->
                    OliloStatusWidgetProvider.saveSource(this, appWidgetId, sourceName)
                    OliloStatusWidgetProvider.refreshWidget(
                        context = this,
                        appWidgetManager = AppWidgetManager.getInstance(this),
                        appWidgetId = appWidgetId,
                    )
                    setResult(
                        RESULT_OK,
                        Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                    )
                    finish()
                },
            )
        }
    }
}

/** Renders the source picker used while adding a widget. */
@Composable
private fun WidgetConfigurationScreen(theme: OliloTheme, onSourceSelected: (String) -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = theme.accentColor,
            background = theme.backgroundColors.top,
            surface = Color(0xD91A1025),
            onSurface = Color.White,
        ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.linearGradient(listOf(
                    theme.backgroundColors.top,
                    theme.backgroundColors.mid,
                    theme.backgroundColors.bottom
                )))
                .windowInsetsPadding(WindowInsets.statusBars)
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(
                "Status Source",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )
            Text(
                "Choose which network source this widget shows.",
                style = MaterialTheme.typography.bodyMedium,
                color = Color(0xFFCEC1D8),
            )
            OliloStatusWidgetProvider.sourceNames.forEach { sourceName ->
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSourceSelected(sourceName) }
                        .semantics {
                            role = Role.Button
                            contentDescription = "Use $sourceName as the widget status source"
                        },
                    shape = RoundedCornerShape(16.dp),
                    color = Color(0xB3261737),
                    contentColor = Color.White,
                ) {
                    Row(
                        modifier = Modifier.padding(18.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(sourceName, modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold)
                        Icon(Icons.Filled.Check, contentDescription = null, tint = theme.accentColor)
                    }
                }
            }
        }
    }
}
