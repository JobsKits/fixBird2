package com.jobs.repair

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.util.Base64
import android.view.MotionEvent
import android.view.View
import java.io.ByteArrayOutputStream

class SignatureView(context: Context) : View(context) {
    private val path = Path()
    private val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.rgb(24, 46, 42); strokeWidth = 5f; style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND }
    private var moves = 0
    init { setBackgroundColor(Color.WHITE); contentDescription = "手写签名区域，请用手指实际签名" }
    fun clear() { path.reset(); moves = 0; invalidate() }
    override fun onDraw(canvas: Canvas) { super.onDraw(canvas); canvas.drawPath(path, ink) }
    override fun onTouchEvent(event: MotionEvent): Boolean {
        parent.requestDisallowInterceptTouchEvent(true)
        when (event.action) {
            MotionEvent.ACTION_DOWN -> path.moveTo(event.x, event.y)
            MotionEvent.ACTION_MOVE -> { path.lineTo(event.x, event.y); moves++ }
            MotionEvent.ACTION_UP -> { performClick(); parent.requestDisallowInterceptTouchEvent(false) }
        }
        invalidate()
        return true
    }
    override fun performClick(): Boolean { super.performClick(); return true }
    fun dataURL(): String {
        require(moves >= 4 && width > 0 && height > 0) { "请实际手写签名后提交" }
        val bitmap = Bitmap.createBitmap(640, 240, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        canvas.scale(640f / width, 240f / height)
        canvas.drawPath(path, ink)
        val buffer = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, buffer)
        bitmap.recycle()
        return "data:image/png;base64," + Base64.encodeToString(buffer.toByteArray(), Base64.NO_WRAP)
    }
}
