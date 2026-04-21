import 'package:flutter/material.dart';
import '../constants/app_constants.dart'; // Add this import

// Custom form fields with consistent styling
class CustomTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final String? Function(String?)? validator;
  final void Function(String) onChanged;
  final bool obscureText;
  final String? helperText;

  const CustomTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.keyboardType,
    required this.textInputAction,
    required this.focusNode,
    this.nextFocusNode,
    this.validator,
    required this.onChanged,
    this.obscureText = false,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        helperText: helperText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: (_) {
        if (nextFocusNode != null) {
          nextFocusNode!.requestFocus();
        } else {
          FocusScope.of(context).unfocus();
        }
      },
    );
  }
}

class CustomDropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final IconData icon;
  final String? Function(T?)? validator;
  final void Function(T?) onChanged;
  final String Function(T) displayText;

  const CustomDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    this.validator,
    required this.onChanged,
    required this.displayText,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            displayText(item),
            style: const TextStyle(fontSize: 16),
          ),
        );
      }).toList(),
      validator: validator,
      onChanged: onChanged,
      isExpanded: true,
    );
  }
}

class DatePickerField extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;
  final String? errorText;

  const DatePickerField({
    super.key,
    required this.selectedDate,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey.shade400,
              width: hasError ? 2.0 : 1.0,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListTile(
            leading: Icon(
              Icons.calendar_today,
              color: hasError ? Colors.red : Colors.grey,
            ),
            title: Text(
              selectedDate == null
                  ? 'Date of Birth* (Must be 18+)'
                  : 'Date of Birth: ${_formatDate(selectedDate!)}',
              style: TextStyle(
                color: hasError ? Colors.red : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class HobbiesSelectionGrid extends StatelessWidget {
  final List<String> selectedHobbies;
  final Function(String, bool) onHobbySelected;
  final String? errorText;

  const HobbiesSelectionGrid({
    super.key,
    required this.selectedHobbies,
    required this.onHobbySelected,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hobbies & Interests*',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppConstants.smallPadding), // Fixed: Added 'const'
        Text(
          selectedHobbies.isEmpty
              ? 'Select at least one hobby'
              : 'Selected: ${selectedHobbies.length}',
          style: TextStyle(
            color: errorText != null ? Colors.red : 
                   selectedHobbies.isEmpty ? Colors.orange : Colors.green,
            fontSize: 14,
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.hobbyOptions // Fixed: Now imported
              .map(
                (hobby) => FilterChip(
                  key: ValueKey(hobby),
                  label: Text(hobby),
                  selected: selectedHobbies.contains(hobby),
                  onSelected: (selected) => onHobbySelected(hobby, selected),
                  checkmarkColor: Colors.white,
                  selectedColor: Colors.blue,
                  labelStyle: TextStyle(
                    color: selectedHobbies.contains(hobby) 
                        ? Colors.white 
                        : Colors.black87,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}