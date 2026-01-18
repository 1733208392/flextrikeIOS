package com.flextarget.android.ui.competition

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import java.text.SimpleDateFormat
import java.util.*

// Placeholder data class for Competition
data class CompetitionItem(
    val id: String,
    val name: String,
    val venue: String,
    val date: Date,
    val drillName: String? = null
)

@Composable
fun CompetitionListView(onBack: () -> Unit) {
    val competitions = remember { mutableStateOf(emptyList<CompetitionItem>()) }
    val searchQuery = remember { mutableStateOf("") }

    val filteredCompetitions = competitions.value.filter { competition ->
        competition.name.contains(searchQuery.value, ignoreCase = true) ||
                competition.venue.contains(searchQuery.value, ignoreCase = true)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Top Bar
        TopAppBar(
            title = { Text("Competitions") },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                }
            },
            actions = {
                IconButton(onClick = { /* Add competition */ }) {
                    Icon(Icons.Default.Add, contentDescription = "Add Competition")
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Color.Black,
                titleContentColor = Color.White,
                navigationIconContentColor = Color.Red,
                actionIconContentColor = Color.Red
            )
        )

        // Search Bar
        SearchBar(
            value = searchQuery.value,
            onValueChange = { searchQuery.value = it },
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp)
        )

        // Competitions List
        if (filteredCompetitions.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "No competitions yet",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(filteredCompetitions) { competition ->
                    CompetitionListItem(competition)
                }
            }
        }
    }
}

@Composable
private fun SearchBar(
    value: String,
    onValueChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier,
        placeholder = { Text("Search competitions...", color = Color.Gray) },
        leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = Color.Gray) },
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = Color.White,
            unfocusedTextColor = Color.White,
            focusedBorderColor = Color.Red,
            unfocusedBorderColor = Color.Gray
        ),
        singleLine = true
    )
}

@Composable
private fun CompetitionListItem(competition: CompetitionItem) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = Color.White.copy(alpha = 0.1f)
            ),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color.White.copy(alpha = 0.05f)
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = competition.name,
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.LocationOn,
                    contentDescription = null,
                    tint = Color.Gray,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = competition.venue,
                    color = Color.Gray,
                    style = MaterialTheme.typography.labelSmall
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.DateRange,
                    contentDescription = null,
                    tint = Color.Gray,
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = SimpleDateFormat("MMM dd, yyyy", Locale.US).format(competition.date),
                    color = Color.Gray,
                    style = MaterialTheme.typography.labelSmall
                )
            }

            competition.drillName?.let {
                Text(
                    text = it,
                    color = Color.Red,
                    style = MaterialTheme.typography.labelSmall,
                    modifier = Modifier
                        .background(
                            color = Color.Red.copy(alpha = 0.2f),
                            shape = RoundedCornerShape(4.dp)
                        )
                        .padding(4.dp)
                )
            }
        }
    }
}
