package net.gameble.app

class PullGesture(private val distance: Float) {
    sealed interface Change {
        data class Pulled(val progress: Float, val reachedFull: Boolean) : Change
        data class LetGo(val refresh: Boolean) : Change
    }

    private var startY: Float? = null
    private var progress = 0f

    fun down(y: Float, atTop: Boolean) {
        startY = y.takeIf { atTop }
        progress = 0f
    }

    fun move(y: Float, atTop: Boolean, blocked: Boolean): Change? {
        val start = startY ?: return null
        if (!atTop || blocked) return cancel()
        val previous = progress
        progress = (y - start).coerceAtLeast(0f) * RESISTANCE / distance
        if (progress == 0f && previous == 0f) return null
        return Change.Pulled(progress.coerceAtMost(1f), reachedFull = progress >= 1f && previous < 1f)
    }

    fun up(): Change? = end(refresh = progress >= 1f)

    fun cancel(): Change? = end(refresh = false)

    private fun end(refresh: Boolean): Change? {
        val wasPulling = startY != null && progress > 0f
        startY = null
        progress = 0f
        return if (wasPulling) Change.LetGo(refresh) else null
    }

    private companion object {
        const val RESISTANCE = 0.5f
    }
}
