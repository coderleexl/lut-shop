package com.lutshop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lutshop.LutShopAppState
import com.lutshop.R

@Composable
fun CameraImportScreen(state: LutShopAppState, onBackToGallery: () -> Unit) {
    LaunchedEffect(Unit) {
        state.refreshFtpHost()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 14.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringResource(R.string.camera_receive), color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            TextButton(onClick = onBackToGallery) {
                Text(stringResource(R.string.back_to_gallery), color = Color.White.copy(alpha = 0.82f), fontWeight = FontWeight.SemiBold)
            }
        }
        Text(stringResource(R.string.hotspot_info), color = Color.White.copy(alpha = 0.6f), fontSize = 14.sp)

        Button(
            onClick = {
                if (state.isFtpReceiverRunning) state.stopFtpReceiver() else state.startFtpReceiver()
            },
            colors = ButtonDefaults.buttonColors(
                containerColor = if (state.isFtpReceiverRunning) Color.White.copy(alpha = 0.14f) else Color(0xFF59E0C5),
                contentColor = if (state.isFtpReceiverRunning) Color.White else Color.Black
            ),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(stringResource(if (state.isFtpReceiverRunning) R.string.stop_receive else R.string.start_receive))
        }

        InfoCard(
            stringResource(R.string.ftp_status),
            if (state.isFtpReceiverRunning) stringResource(R.string.ftp_receiver_running) else stringResource(R.string.ftp_receiver_stopped)
        )
        InfoCard(stringResource(R.string.ftp_current_file), state.ftpCurrentFileName.ifBlank {
            if (state.isFtpReceiverRunning) stringResource(R.string.waiting_for_camera) else "-"
        })
        InfoCard(stringResource(R.string.ftp_received), state.ftpReceivedCount.toString())
        InfoCard(stringResource(R.string.ftp_host), state.ftpConfiguration.host)
        InfoCard(stringResource(R.string.ftp_port), state.ftpConfiguration.port.toString())
        InfoCard(stringResource(R.string.ftp_user), state.ftpConfiguration.username)
        InfoCard(stringResource(R.string.ftp_pass), state.ftpConfiguration.password)
        InfoCard(stringResource(R.string.ftp_last_file), state.ftpLastFileName.ifBlank { "-" })

        Text(
            state.ftpStatusMessage.ifBlank { stringResource(R.string.ftp_android_ready_detail) },
            color = Color.White.copy(alpha = 0.5f),
            fontSize = 13.sp
        )

        Spacer(Modifier.height(18.dp))
    }
}

@Composable
private fun InfoCard(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.08f))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, color = Color.White.copy(alpha = 0.6f), fontSize = 14.sp, modifier = Modifier.weight(1f))
        Text(value, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Medium)
    }
}
